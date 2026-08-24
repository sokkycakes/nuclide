/* Editable UI logic — no Go rebuild needed when this file changes (if loose ui/ is used). */

const $ = (id) => document.getElementById(id);

function setStatus(msg, kind) {
  const el = $("status");
  el.textContent = msg;
  el.classList.remove("error", "ok");
  if (kind) el.classList.add(kind);
}

function setBusy(busy) {
  $("btnCheck").disabled = busy;
  $("btnUpdate").disabled = busy || !$("btnUpdate").dataset.ready;
  $("btnLaunch").disabled = busy;
}

async function refreshStatus() {
  const s = await getStatus();
  $("localVersion").textContent = s.localVersion || "(none)";
  $("gameDir").textContent = s.gameDir || "—";
  $("gameDir").title = s.gameDir || "";
  if (s.gameRunning) {
    setStatus("Game is running — close it before updating.", "error");
  }
  return s;
}

async function onCheck() {
  setBusy(true);
  setStatus("Checking…");
  try {
    await refreshStatus();
    const r = await checkUpdate();
    $("localVersion").textContent = r.localVersion || "(none)";
    $("remoteVersion").textContent = r.remoteVersion || "—";
    const notes = $("notes");
    if (r.notes) {
      notes.hidden = false;
      notes.textContent = r.notes;
    } else {
      notes.hidden = true;
    }
    if (r.updateAvailable) {
      $("btnUpdate").dataset.ready = "1";
      $("btnUpdate").disabled = false;
      setStatus(`Update available: ${r.remoteVersion}`, "ok");
    } else {
      delete $("btnUpdate").dataset.ready;
      $("btnUpdate").disabled = true;
      setStatus("Already up to date.", "ok");
    }
  } catch (e) {
    setStatus(String(e), "error");
    delete $("btnUpdate").dataset.ready;
    $("btnUpdate").disabled = true;
  } finally {
    setBusy(false);
  }
}

async function onUpdate() {
  setBusy(true);
  setStatus("Downloading / applying…");
  try {
    const r = await applyUpdate();
    $("localVersion").textContent = r.version || "—";
    $("remoteVersion").textContent = r.version || "—";
    delete $("btnUpdate").dataset.ready;
    $("btnUpdate").disabled = true;
    setStatus(r.message || "Done.", "ok");
  } catch (e) {
    setStatus(String(e), "error");
  } finally {
    setBusy(false);
  }
}

async function onLaunch() {
  setBusy(true);
  setStatus("Launching…");
  try {
    await launchGame();
    setStatus("Game launched.", "ok");
  } catch (e) {
    setStatus(String(e), "error");
  } finally {
    setBusy(false);
  }
}

window.addEventListener("DOMContentLoaded", async () => {
  $("btnCheck").addEventListener("click", onCheck);
  $("btnUpdate").addEventListener("click", onUpdate);
  $("btnLaunch").addEventListener("click", onLaunch);
  try {
    const cfg = await getConfig();
    if (cfg.windowTitle) {
      document.title = cfg.windowTitle;
      $("title").textContent = cfg.windowTitle.replace(/\s*Updater\s*$/i, "") || "Nuclide Playtest";
    }
    await refreshStatus();
    setStatus("Ready. Click Check.");
  } catch (e) {
    setStatus(String(e), "error");
  }
});
