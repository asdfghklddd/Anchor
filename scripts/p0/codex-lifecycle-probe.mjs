import { open } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const lifecycleTypes = new Set(['task_started', 'task_complete', 'turn_aborted']);
const digest = value => createHash('sha256').update(value).digest('hex');

// Diagnostic only: the caller selects one source file and owns the checkpoint.
// Never persist raw lines, message text, tool arguments, or real source IDs.
export async function probe(path, expectedSessionID, checkpoint = null, options = {}) {
  const maxLineBytes = options.maxLineBytes ?? 2 * 1024 * 1024;
  const chunkBytes = options.chunkBytes ?? 256 * 1024;
  const maxScanBytes = options.maxScanBytes ?? 128 * 1024 * 1024;
  const file = await open(path, 'r');
  try {
    const stat = await file.stat();
    const identity = `${stat.dev}:${stat.ino}:${stat.birthtimeMs}`;
    if (checkpoint && checkpoint.identity !== identity) {
      return { resetRequired: true, reason: 'file_replaced' };
    }
    if (checkpoint && (!Number.isSafeInteger(checkpoint.offset) || checkpoint.offset < 0)) {
      throw new Error('Invalid checkpoint offset');
    }
    if (checkpoint && stat.size < checkpoint.offset) {
      return { resetRequired: true, reason: 'file_truncated' };
    }
    const header = Buffer.alloc(Math.min(stat.size, maxLineBytes));
    await file.read(header, 0, header.length, 0);
    const end = header.indexOf(10);
    if (end < 0) throw new Error('Missing or oversized complete session header');
    let meta;
    try { meta = JSON.parse(header.subarray(0, end).toString('utf8')); }
    catch { throw new Error('Invalid session header'); }
    if (meta.type !== 'session_meta' || meta.payload?.id !== expectedSessionID) {
      throw new Error('Selected source does not match expected session');
    }
    const scope = digest(expectedSessionID);
    if (checkpoint && checkpoint.scope !== scope) throw new Error('Checkpoint scope mismatch');
    let offset = checkpoint?.offset ?? 0;
    const initialOffset = offset;
    const boundary = Math.min(stat.size, initialOffset + maxScanBytes);
    let committed = offset;
    let dropping = checkpoint?.dropping ?? false;
    let pending = Buffer.alloc(0);
    const seen = new Set(checkpoint?.seen ?? []);
    const events = [];
    const counts = { malformed: 0, oversized: 0, duplicates: 0, ignored: 0 };
    while (offset < boundary) {
      const bytes = Buffer.alloc(Math.min(chunkBytes, boundary - offset));
      const { bytesRead } = await file.read(bytes, 0, bytes.length, offset);
      if (!bytesRead) break;
      let start = 0;
      for (let i = 0; i < bytesRead; i++) {
        if (bytes[i] !== 10) continue;
        const part = bytes.subarray(start, i);
        if (!dropping && pending.length + part.length <= maxLineBytes) {
          const line = Buffer.concat([pending, part]);
          try {
            const record = JSON.parse(line.toString('utf8'));
            const p = record.payload;
            if (record.type === 'event_msg' && lifecycleTypes.has(p?.type)
                && typeof p.turn_id === 'string' && p.turn_id.length <= 128
                && typeof record.timestamp === 'string' && Number.isFinite(Date.parse(record.timestamp))) {
              const key = digest(`${scope}:${p.turn_id}:${p.type}`);
              if (seen.has(key)) counts.duplicates++;
              else {
                if (seen.size >= 10000) throw new Error('Diagnostic event limit exceeded');
                seen.add(key);
                events.push({ eventID: key, runAlias: digest(`${scope}:${p.turn_id}`).slice(0, 16),
                  type: p.type, at: new Date(record.timestamp).toISOString() });
              }
            } else counts.ignored++;
          } catch (error) {
            if (!(error instanceof SyntaxError)) throw error;
            counts.malformed++;
          }
        } else if (!dropping) counts.oversized++;
        pending = Buffer.alloc(0);
        dropping = false;
        committed = offset + i + 1;
        start = i + 1;
      }
      if (!dropping) {
        pending = Buffer.concat([pending, bytes.subarray(start, bytesRead)]);
        if (pending.length > maxLineBytes) {
          pending = Buffer.alloc(0);
          dropping = true;
          counts.oversized++;
        }
      }
      offset += bytesRead;
      // Partial JSON is reread next time; an oversized line is skipped to its newline.
      if (dropping) committed = offset;
    }
    return {
      resetRequired: false, events, counts,
      scannedBytes: offset - initialOffset,
      partialRecordDeferred: pending.length > 0,
      checkpoint: { identity, scope, offset: committed, dropping, seen: [...seen] },
    };
  } finally { await file.close(); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [path, sessionID] = process.argv.slice(2);
  if (!path || !sessionID) {
    process.stderr.write('Usage: node codex-lifecycle-probe.mjs FILE EXPECTED_SESSION_ID\n');
    process.exitCode = 2;
  } else {
    try { process.stdout.write(`${JSON.stringify(await probe(path, sessionID), null, 2)}\n`); }
    catch { process.stderr.write('Probe failed; no source content printed.\n'); process.exitCode = 1; }
  }
}
