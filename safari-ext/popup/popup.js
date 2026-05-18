const ext = globalThis.browser ?? globalThis.chrome;

const statusEl = document.getElementById("status");
const countEl = document.getElementById("count");

ext.runtime.sendMessage({ type: "stats" }, (resp) => {
  if (!resp) {
    statusEl.textContent = "Engine not responding";
    return;
  }
  statusEl.textContent = resp.ready ? "Engine running" : "Engine starting";
  countEl.textContent = `${resp.blocked} blocked`;
});
