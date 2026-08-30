const SESSION_KEY = "anchorWebObservationState";
const INITIAL_STATE = { sequence: 0, currentTabID: null, tabs: {} };

// Serialize tab callbacks so lifecycle sequence numbers stay deterministic.
let operationQueue = Promise.resolve();

function enqueue(operation) {
  operationQueue = operationQueue.then(operation, operation);
  return operationQueue;
}

async function loadSessionState() {
  const stored = await browser.storage.session.get(SESSION_KEY);
  const state = stored[SESSION_KEY];
  return state && typeof state === "object"
    ? state
    : structuredClone(INITIAL_STATE);
}

async function saveSessionState(state) {
  await browser.storage.session.set({ [SESSION_KEY]: state });
}

async function isEnabled() {
  const stored = await browser.storage.local.get({ enabled: false });
  return stored.enabled === true;
}

function hostnameForTab(tab) {
  if (!tab || tab.incognito || typeof tab.url !== "string") {
    return null;
  }
  try {
    const url = new URL(tab.url);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      return null;
    }
    return url.hostname.toLowerCase();
  } catch {
    return null;
  }
}

async function deliver(signal) {
  try {
    const response = await browser.runtime.sendNativeMessage(signal);
    if (!response || response.ok !== true) {
      throw new Error("Native host rejected the signal.");
    }
    await browser.storage.local.set({
      bridgeStatus: "connected",
      lastDeliveryAt: new Date().toISOString()
    });
    return true;
  } catch {
    await browser.storage.local.set({ bridgeStatus: "unavailable" });
    return false;
  }
}

async function sendState(entry, activityState, state) {
  state.sequence += 1;
  const signal = {
    id: crypto.randomUUID(),
    schema: "anchor.web.activity.v1",
    activityID: entry.activityID,
    sequence: state.sequence,
    state: activityState,
    occurredAt: new Date().toISOString(),
    siteHost: entry.siteHost,
    browserName: "Safari"
  };
  const delivered = await deliver(signal);
  if (delivered) {
    entry.lastState = activityState;
  }
  return delivered;
}

async function backgroundCurrent(state) {
  if (state.currentTabID === null) {
    return;
  }
  const entry = state.tabs[String(state.currentTabID)];
  if (entry && entry.lastState !== "background" && entry.lastState !== "closed") {
    await sendState(entry, "background", state);
  }
  state.currentTabID = null;
}

async function observeActiveTab() {
  if (!(await isEnabled())) {
    return;
  }

  const [tab] = await browser.tabs.query({ active: true, lastFocusedWindow: true });
  const siteHost = hostnameForTab(tab);
  const state = await loadSessionState();
  if (!tab || typeof tab.id !== "number" || !siteHost) {
    await backgroundCurrent(state);
    await saveSessionState(state);
    return;
  }

  const tabKey = String(tab.id);
  if (state.currentTabID !== null && state.currentTabID !== tab.id) {
    await backgroundCurrent(state);
  }

  let entry = state.tabs[tabKey];
  if (entry && entry.siteHost !== siteHost) {
    if (entry.lastState !== "closed") {
      await sendState(entry, "closed", state);
    }
    entry = null;
  }
  if (!entry) {
    entry = {
      activityID: crypto.randomUUID(),
      siteHost,
      lastState: null
    };
    state.tabs[tabKey] = entry;
  }

  state.currentTabID = tab.id;
  if (entry.lastState !== "active") {
    await sendState(entry, "active", state);
  }
  await saveSessionState(state);
}

async function closeTab(tabID) {
  const state = await loadSessionState();
  const tabKey = String(tabID);
  const entry = state.tabs[tabKey];
  if (!entry) {
    return;
  }
  if (entry.lastState !== "closed") {
    await sendState(entry, "closed", state);
  }
  delete state.tabs[tabKey];
  if (state.currentTabID === tabID) {
    state.currentTabID = null;
  }
  await saveSessionState(state);
}

async function setEnabled(enabled) {
  if (enabled) {
    await browser.storage.local.set({ enabled: true, bridgeStatus: "connecting" });
    await observeActiveTab();
    return;
  }

  const state = await loadSessionState();
  for (const entry of Object.values(state.tabs)) {
    if (entry.lastState !== "closed") {
      await sendState(entry, "closed", state);
    }
  }
  await browser.storage.session.set({
    [SESSION_KEY]: structuredClone(INITIAL_STATE)
  });
  await browser.storage.local.set({ enabled: false, bridgeStatus: "disabled" });
}

browser.runtime.onInstalled.addListener((details) => {
  void enqueue(async () => {
    const stored = await browser.storage.local.get("enabled");
    if (typeof stored.enabled !== "boolean") {
      const enabled = details.reason === "install";
      await browser.storage.local.set({
        enabled,
        bridgeStatus: enabled ? "connecting" : "disabled"
      });
      if (enabled) {
        await observeActiveTab();
      }
    }
  });
});

browser.runtime.onStartup.addListener(() => {
  void enqueue(observeActiveTab);
});

browser.tabs.onActivated.addListener(() => {
  void enqueue(observeActiveTab);
});

browser.tabs.onUpdated.addListener((tabID, changeInfo, tab) => {
  if (tab.active && (changeInfo.url || changeInfo.status === "complete")) {
    void enqueue(observeActiveTab);
  }
});

browser.tabs.onRemoved.addListener((tabID) => {
  void enqueue(() => closeTab(tabID));
});

browser.windows.onFocusChanged.addListener((windowID) => {
  void enqueue(async () => {
    if (windowID === browser.windows.WINDOW_ID_NONE) {
      const state = await loadSessionState();
      await backgroundCurrent(state);
      await saveSessionState(state);
    } else {
      await observeActiveTab();
    }
  });
});

browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "anchor.setEnabled") {
    return false;
  }
  void enqueue(() => setEnabled(message.enabled === true))
    .then(() => sendResponse({ ok: true }))
    .catch(() => sendResponse({ ok: false }));
  return true;
});
