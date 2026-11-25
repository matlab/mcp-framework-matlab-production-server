// Copyright 2026 The MathWorks, Inc.

import { App, type McpUiHostContext } from "@modelcontextprotocol/ext-apps";
import { renderChart, type DisplayMode } from "./chart";
import {
  errorText,
  fetchSignal,
  runPassChain,
  parseCSV,
  type CleaningPass,
} from "./passes";
import "./global.css";

// DOM elements
const statusEl = document.getElementById("status")!;
const controlsEl = document.getElementById("controls")!;
const fileUrlEl = document.getElementById("file-url") as HTMLInputElement;
const frequencyEl = document.getElementById("frequency") as HTMLInputElement;
const addPassBtn = document.getElementById("add-pass")!;
const passListEl = document.getElementById("pass-list")!;
const chartCanvas = document.getElementById("chart") as HTMLCanvasElement;
const modeRadios = document.querySelectorAll<HTMLInputElement>(
  'input[name="mode"]',
);

// State
let originalURL = "";
let originalSignal: number[] = [];
let cleanSignal: number[] = [];
let passes: CleaningPass[] = [];
let displayMode: DisplayMode = "both";

const app = new App({ name: "Clean Signal", version: "1.0.0" });

function setStatus(msg: string) {
  statusEl.textContent = msg;
  statusEl.classList.toggle("hidden", !msg);
}

function showControls() {
  controlsEl.classList.remove("hidden");
}

function redraw() {
  renderChart({
    canvas: chartCanvas,
    original: originalSignal,
    clean: cleanSignal,
    mode: displayMode,
  });
}

function renderPassList() {
  passListEl.innerHTML = "";
  passes.forEach((p, i) => {
    const tag = document.createElement("span");
    tag.className = "pass-tag";
    tag.textContent = `${p.frequency} Hz`;

    const removeBtn = document.createElement("button");
    removeBtn.textContent = "×";
    removeBtn.addEventListener("click", () => removePass(i));
    tag.appendChild(removeBtn);

    passListEl.appendChild(tag);
  });
}

async function removePass(index: number) {
  passes.splice(index, 1);
  renderPassList();
  await rerunChain();
}

async function rerunChain() {
  if (passes.length === 0) {
    cleanSignal = [...originalSignal];
    redraw();
    return;
  }

  setStatus("Cleaning...");
  try {
    const cleanURL = await runPassChain(app, originalURL, passes);
    cleanSignal = await fetchSignal(app, cleanURL);
    redraw();
    setStatus("");
  } catch (e) {
    setStatus(`Error: ${e instanceof Error ? e.message : String(e)}`);
  }
}

function applyHostContext(ctx: McpUiHostContext) {
  if (ctx.theme) {
    document.documentElement.setAttribute("data-theme", ctx.theme);
  }
}

// Register handlers before connect
app.ontoolinput = (params) => {
  const args = params.arguments as Record<string, unknown> | undefined;
  if (args?.noisyURL) {
    originalURL = String(args.noisyURL);
    fileUrlEl.value = originalURL;
  }
  if (args?.frequency) {
    frequencyEl.value = String(args.frequency);
  }
  setStatus("Processing...");
};

app.ontoolresult = async (result) => {
  showControls();

  // The model's call failed: say why, and record no pass.
  if (result.isError) {
    setStatus(`Error: ${errorText(result)}`);
    return;
  }

  // Extract clean URL from structuredContent
  const sc = result.structuredContent as Record<string, unknown> | undefined;
  const cleanURL = sc?.cleanURL as string | undefined;

  try {
    // Fetch original signal
    if (originalURL && originalSignal.length === 0) {
      setStatus("Fetching original signal...");
      originalSignal = await fetchSignal(app, originalURL);
      setStatus(`Original: ${originalSignal.length} samples`);
    }

    // Fetch clean signal from result
    if (cleanURL) {
      setStatus("Fetching clean signal...");
      cleanSignal = await fetchSignal(app, cleanURL);
      setStatus(`Clean: ${cleanSignal.length} samples`);
    } else {
      // Try parsing from text content
      const textContent = result.content?.find(
        (c: { type: string }) => c.type === "text",
      ) as { text: string } | undefined;
      if (textContent?.text) {
        try {
          const parsed = JSON.parse(textContent.text);
          if (parsed.cleanURL) {
            setStatus("Fetching clean signal...");
            cleanSignal = await fetchSignal(app, parsed.cleanURL);
            setStatus(`Clean: ${cleanSignal.length} samples`);
          }
        } catch {
          cleanSignal = parseCSV(textContent.text);
          setStatus(`Parsed inline: ${cleanSignal.length} samples`);
        }
      } else {
        setStatus("No cleanURL in structuredContent or text content");
      }
    }

    // Record the initial pass
    const freq = parseFloat(frequencyEl.value);
    if (passes.length === 0 && !isNaN(freq)) {
      passes.push({ frequency: freq });
      renderPassList();
    }

    redraw();
    if (originalSignal.length > 0 || cleanSignal.length > 0) {
      setStatus("");
    }
  } catch (e) {
    setStatus(`Error: ${e instanceof Error ? e.message : String(e)}`);
  }
};

app.ontoolcancelled = () => {
  setStatus("Cancelled");
};

app.onhostcontextchanged = applyHostContext;

app.onteardown = async () => {
  return {};
};

// UI event listeners
addPassBtn.addEventListener("click", async () => {
  const freq = parseFloat(frequencyEl.value);
  // cleanSignal accepts frequencies strictly between 1 and 499 Hz.
  if (isNaN(freq) || freq <= 1 || freq >= 499) return;
  passes.push({ frequency: freq });
  renderPassList();
  await rerunChain();
});

modeRadios.forEach((radio) => {
  radio.addEventListener("change", () => {
    displayMode = radio.value as DisplayMode;
    redraw();
  });
});

window.addEventListener("resize", redraw);

// Connect
app.connect().then(() => {
  const ctx = app.getHostContext();
  if (ctx) applyHostContext(ctx);
  setStatus("Connected. Waiting for tool call...");
});
