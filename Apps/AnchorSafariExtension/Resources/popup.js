const enabledInput = document.querySelector("#enabled");
const status = document.querySelector("#status");

function message(key, fallback) {
  return browser.i18n.getMessage(key) || fallback;
}

function localizeDocument() {
  document.documentElement.lang = browser.i18n.getUILanguage().split("-")[0] || "en";
  for (const element of document.querySelectorAll("[data-i18n]")) {
    element.textContent = message(element.dataset.i18n, element.textContent.trim());
  }
}

function statusText(enabled, bridgeStatus) {
  if (!enabled) {
    return message("disabledStatus", "Observation is off.");
  }
  switch (bridgeStatus) {
  case "connected":
    return message("connectedStatus", "Connected to Anchor.");
  case "unavailable":
    return message("unavailableStatus", "Anchor bridge is unavailable.");
  default:
    return message("connectingStatus", "Connecting to Anchor…");
  }
}

async function render() {
  const stored = await browser.storage.local.get({
    enabled: true,
    bridgeStatus: "connecting"
  });
  enabledInput.checked = stored.enabled === true;
  status.textContent = statusText(enabledInput.checked, stored.bridgeStatus);
}

enabledInput.addEventListener("change", async () => {
  enabledInput.setAttribute("aria-busy", "true");
  status.textContent = message("updatingStatus", "Updating…");
  try {
    const response = await browser.runtime.sendMessage({
      type: "anchor.setEnabled",
      enabled: enabledInput.checked
    });
    if (!response || response.ok !== true) {
      throw new Error("The background service rejected the update.");
    }
  } catch {
    status.textContent = message("updateFailedStatus", "Could not update observation.");
  } finally {
    enabledInput.removeAttribute("aria-busy");
    await render();
  }
});

browser.storage.onChanged.addListener((changes, areaName) => {
  if (areaName === "local" && (changes.enabled || changes.bridgeStatus)) {
    void render();
  }
});

localizeDocument();
void render();
