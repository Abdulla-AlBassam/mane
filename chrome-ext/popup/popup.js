const ext = globalThis.browser ?? globalThis.chrome;

const statusEl = document.getElementById("status");
const countEl = document.getElementById("count");
const toggleEl = document.getElementById("toggle");

let currentEnabled = true;

function render(resp) {
  if (!resp) {
    statusEl.textContent = "Engine not responding";
    toggleEl.classList.add("disabled");
    return;
  }
  if (!resp.ready) {
    statusEl.textContent = "Engine starting";
    toggleEl.classList.add("disabled");
  } else if (resp.enabled === false) {
    statusEl.textContent = "Engine paused";
    toggleEl.classList.remove("disabled");
  } else {
    statusEl.textContent = "Engine running";
    toggleEl.classList.remove("disabled");
  }
  countEl.textContent = `${resp.blocked ?? 0} blocked`;
  currentEnabled = resp.enabled !== false;
  toggleEl.classList.toggle("on", currentEnabled);
  toggleEl.setAttribute("aria-checked", String(currentEnabled));
}

function handleToggle() {
  if (toggleEl.classList.contains("disabled")) return;
  const next = !currentEnabled;
  ext.runtime.sendMessage({ type: "setEnabled", enabled: next }, (resp) => render(resp));
}

toggleEl.addEventListener("click", handleToggle);
toggleEl.addEventListener("keydown", (e) => {
  if (e.key === " " || e.key === "Enter") {
    e.preventDefault();
    handleToggle();
  }
});

ext.runtime.sendMessage({ type: "stats" }, render);
