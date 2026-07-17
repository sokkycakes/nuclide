(async () => {
  const status = document.querySelector("#status");
  const output = document.querySelector("#result");

  try {
    const response = await fetch("smoke.json");
    const payload = await response.json();
    status.textContent = payload.message;
  } catch (error) {
    status.textContent = `Local fetch failed: ${error.message}`;
  }

  document.querySelector("#query").addEventListener("click", () => {
    if (typeof window.fte_query !== "function") {
      output.textContent = "FTE bridge unavailable";
      return;
    }
    output.textContent = window.fte_query("getstats");
  });
})();
