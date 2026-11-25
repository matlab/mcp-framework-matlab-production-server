// Copyright 2026 The MathWorks, Inc.

export type DisplayMode = "original" | "clean" | "both";

interface ChartOptions {
  canvas: HTMLCanvasElement;
  original: number[];
  clean: number[];
  mode: DisplayMode;
}

const COLOR_ORIGINAL = getComputedStyle(document.documentElement)
  .getPropertyValue("--color-original")
  .trim() || "#888888";

const COLOR_CLEAN = getComputedStyle(document.documentElement)
  .getPropertyValue("--color-clean")
  .trim() || "#16a34a";

export function renderChart({ canvas, original, clean, mode }: ChartOptions) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  ctx.scale(dpr, dpr);

  const w = rect.width;
  const h = rect.height;
  const pad = { top: 10, right: 10, bottom: 30, left: 50 };
  const plotW = w - pad.left - pad.right;
  const plotH = h - pad.top - pad.bottom;

  ctx.clearRect(0, 0, w, h);

  const visible: number[] = [];
  if (mode === "original" || mode === "both") visible.push(...original);
  if (mode === "clean" || mode === "both") visible.push(...clean);

  // NaN and the infinities have no place on the axis.
  const finite = visible.filter(Number.isFinite);
  if (finite.length === 0) return;

  const yMin = Math.min(...finite);
  const yMax = Math.max(...finite);
  const yRange = yMax - yMin || 1;

  const n = Math.max(original.length, clean.length);

  function toX(i: number): number {
    return pad.left + (i / (n - 1 || 1)) * plotW;
  }
  function toY(v: number): number {
    return pad.top + plotH - ((v - yMin) / yRange) * plotH;
  }

  // Axes
  ctx.strokeStyle = getComputedStyle(document.documentElement)
    .getPropertyValue("--color-border")
    .trim() || "#e0e0e0";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(pad.left, pad.top);
  ctx.lineTo(pad.left, pad.top + plotH);
  ctx.lineTo(pad.left + plotW, pad.top + plotH);
  ctx.stroke();

  // Y-axis labels
  ctx.fillStyle = getComputedStyle(document.documentElement)
    .getPropertyValue("--color-text-secondary")
    .trim() || "#666666";
  ctx.font = `11px ${getComputedStyle(document.documentElement).getPropertyValue("--font-mono").trim() || "monospace"}`;
  ctx.textAlign = "right";
  ctx.textBaseline = "middle";
  const yTicks = 5;
  for (let i = 0; i <= yTicks; i++) {
    const v = yMin + (yRange * i) / yTicks;
    const y = toY(v);
    ctx.fillText(v.toFixed(1), pad.left - 6, y);
  }

  // X-axis label
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText(`Sample (0–${n - 1})`, pad.left + plotW / 2, pad.top + plotH + 14);

  function drawTrace(data: number[], color: string) {
    if (data.length === 0) return;
    ctx!.strokeStyle = color;
    ctx!.lineWidth = 1.2;
    ctx!.beginPath();
    // Downsample if more points than pixels
    const step = Math.max(1, Math.floor(data.length / plotW));
    // A value that isn't finite breaks the line.
    let drawing = false;
    for (let i = 0; i < data.length; i += step) {
      if (!Number.isFinite(data[i])) {
        drawing = false;
        continue;
      }
      const x = toX(i);
      const y = toY(data[i]);
      if (!drawing) ctx!.moveTo(x, y);
      else ctx!.lineTo(x, y);
      drawing = true;
    }
    ctx!.stroke();
  }

  if (mode === "original" || mode === "both") {
    drawTrace(original, COLOR_ORIGINAL);
  }
  if (mode === "clean" || mode === "both") {
    drawTrace(clean, COLOR_CLEAN);
  }
}
