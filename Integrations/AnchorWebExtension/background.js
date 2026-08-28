const HOST_NAME = "com.andywang.anchor.web";
const SESSION_KEY = "anchorWebObservationState";
const INITIAL_STATE = { sequence: 0, currentTabID: null, tabs: {} };

let operationQueue = Promise.resolve();

function enqueue(operation) {
  operationQueue = operationQueue.then(operation, operation);
  return operationQueue;
}

async function loadSessionState() {
  const stored = await chrome.storage.session.get(SESSION_KEY);
  const state = stored[SESSION_KEY];
  return state && typeof state === "object"
    ? state
    : structuredClone(INITIAL_STATE);
}

async function saveSessionState(state) {
  await chrome.storage.session.set({ [SESSION_KEY]: state });
}

async function isEnabled() {
  const stored = await chrome.storage.local.get({ enabled: false });
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
    const response = await chrome.runtime.sendNativeMessage(HOST_NAME, signal);
    if (!response || response.ok !== true) {
      throw new Error("Native host rejected the signal.");
    }
    await chrome.storage.local.set({
      bridgeStatus: "connected",
      lastDeliveryAt: new Date().toISOString()
    });
    return true;
  } catch {
    await chrome.storage.local.set({ bridgeStatus: "unavailable" });
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
    browserName: "Browser"
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

  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
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
    await chrome.storage.local.set({ enabled: true, bridgeStatus: "connecting" });
    await observeActiveTab();
    return;
  }

  const state = await loadSessionState();
  for (const entry of Object.values(state.tabs)) {
    if (entry.lastState !== "closed") {
      await sendState(entry, "closed", state);
    }
  }
  await chrome.storage.session.set({
    [SESSION_KEY]: structuredClone(INITIAL_STATE)
  });
  await chrome.storage.local.set({ enabled: false, bridgeStatus: "disabled" });
}

chrome.runtime.onInstalled.addListener((details) => {
  void enqueue(async () => {
    const stored = await chrome.storage.local.get("enabled");
    if (typeof stored.enabled !== "boolean") {
      const enabled = details.reason === "install";
      await chrome.storage.local.set({
        enabled,
        bridgeStatus: enabled ? "connecting" : "disabled"
      });
      if (enabled) {
        await observeActiveTab();
      }
    }
  });
});

chrome.runtime.onStartup.addListener(() => {
  void enqueue(observeActiveTab);
});

chrome.tabs.onActivated.addListener(() => {
  void enqueue(observeActiveTab);
});

chrome.tabs.onUpdated.addListener((tabID, changeInfo, tab) => {
  if (tab.active && (changeInfo.url || changeInfo.status === "complete")) {
    void enqueue(observeActiveTab);
  }
});

chrome.tabs.onRemoved.addListener((tabID) => {
  void enqueue(() => closeTab(tabID));
});

chrome.windows.onFocusChanged.addListener((windowID) => {
  void enqueue(async () => {
    if (windowID === chrome.windows.WINDOW_ID_NONE) {
      const state = await loadSessionState();
      await backgroundCurrent(state);
      await saveSessionState(state);
    } else {
      await observeActiveTab();
    }
  });
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "anchor.setEnabled") {
    return false;
  }
  void enqueue(() => setEnabled(message.enabled === true))
    .then(() => sendResponse({ ok: true }))
    .catch(() => sendResponse({ ok: false }));
  return true;
});
