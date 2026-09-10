import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, appendFile, rename } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { probe } from './codex-lifecycle-probe.mjs';

const sessionID = 'test-session';
const header = JSON.stringify({ type: 'session_meta', payload: { id: sessionID } }) + '\n';
const line = (type, turn = 'one') => JSON.stringify({ timestamp: '2026-09-04T06:00:00Z',
  type: 'event_msg', payload: { type, turn_id: turn, last_agent_message: 'DO_NOT_EXPORT_SECRET' } }) + '\n';
async function fixture(contents) {
  const directory = await mkdtemp(join(tmpdir(), 'anchor-p0-probe-test-'));
  const path = join(directory, 'source.jsonl');
  await writeFile(path, header + contents);
  return path;
}

test('same session has separate runs and never exports content or raw IDs', async () => {
  const path = await fixture(line('task_started') + line('task_complete') + line('task_started', 'two'));
  const result = await probe(path, sessionID, null, { chunkBytes: 17 });
  assert.equal(result.events.length, 3);
  assert.equal(result.events[0].runAlias, result.events[1].runAlias);
  assert.notEqual(result.events[0].runAlias, result.events[2].runAlias);
  assert.equal(JSON.stringify(result).includes('DO_NOT_EXPORT_SECRET'), false);
  assert.equal(JSON.stringify(result).includes(sessionID), false);
});

test('checkpoint skips prior records and deduplicates repeated lifecycle records', async () => {
  const path = await fixture(line('task_started'));
  const first = await probe(path, sessionID);
  const second = await probe(path, sessionID, JSON.parse(JSON.stringify(first.checkpoint)));
  assert.equal(second.events.length, 0);
  await appendFile(path, line('task_started') + line('task_complete'));
  const third = await probe(path, sessionID, second.checkpoint);
  assert.equal(third.events.length, 1);
  assert.equal(third.counts.duplicates, 1);
});

test('partial last record is withheld then emitted exactly once', async () => {
  const full = line('turn_aborted');
  const path = await fixture(full.slice(0, -5));
  const first = await probe(path, sessionID, null, { chunkBytes: 19 });
  assert.equal(first.events.length, 0);
  assert.equal(first.partialRecordDeferred, true);
  await appendFile(path, full.slice(-5));
  const second = await probe(path, sessionID, first.checkpoint);
  assert.equal(second.events.length, 1);
  assert.equal(second.events[0].type, 'turn_aborted');
});

test('rejects wrong session and cross-scope checkpoint', async () => {
  const path = await fixture(line('task_started'));
  await assert.rejects(probe(path, 'another-session'), /expected session/);
  const result = await probe(path, sessionID);
  await assert.rejects(probe(path, sessionID, { ...result.checkpoint, scope: 'wrong' }), /scope/);
});

test('reports file truncation and replacement without automatically rebinding', async () => {
  const path = await fixture(line('task_started'));
  const first = await probe(path, sessionID);
  await writeFile(path, header);
  assert.equal((await probe(path, sessionID, first.checkpoint)).reason, 'file_truncated');
  const replacement = path + '.replacement';
  await writeFile(replacement, header + line('task_started'));
  await rename(replacement, path);
  assert.equal((await probe(path, sessionID, first.checkpoint)).reason, 'file_replaced');
});

test('malformed and oversized lines do not hide a following valid event', async () => {
  const path = await fixture('{broken}\n' + 'x'.repeat(1000) + '\n' + line('task_started'));
  const result = await probe(path, sessionID, null, { maxLineBytes: 256, chunkBytes: 37 });
  assert.equal(result.counts.malformed, 1);
  assert.equal(result.counts.oversized, 1);
  assert.equal(result.events.length, 1);
});

test('oversized unfinished line preserves skip state across bounded scans', async () => {
  const path = await fixture('x'.repeat(1200));
  const first = await probe(path, sessionID, null, { maxLineBytes: 256, maxScanBytes: 512 });
  assert.equal(first.checkpoint.dropping, true);
  await appendFile(path, '\n' + line('task_complete'));
  const second = await probe(path, sessionID, first.checkpoint, { maxLineBytes: 256 });
  assert.equal(second.events.length, 1);
  assert.equal(second.events[0].type, 'task_complete');
});
