// Copyright 2026 The MathWorks, Inc.

import type { App } from "@modelcontextprotocol/ext-apps";

export interface CleaningPass {
  frequency: number;
}

type ToolResult = Awaited<ReturnType<App["callServerTool"]>>;

export function parseCSV(text: string): number[] {
  return text
    .trim()
    .split(/[\r\n]+/)
    .map((line) => parseFloat(line))
    .filter((v) => !isNaN(v));
}

// The text a tool error carries: the server's message.
export function errorText(result: ToolResult): string {
  const texts = (result.content ?? [])
    .filter((c: { type: string }) => c.type === "text")
    .map((c) => (c as { text: string }).text);
  return texts.join(" ") || "the tool reported an error";
}

// A tool error comes back as a result with isError set, not as an
// exception, so check every result.
function requireSuccess(result: ToolResult, tool: string): void {
  if (result.isError) {
    throw new Error(`${tool} failed: ${errorText(result)}`);
  }
}

// A number as plain JSON sends it: null for NaN, the text "Inf" or
// "-Inf" for an infinity.
function toNumber(v: unknown): number {
  if (typeof v === "number") return v;
  if (v === "Inf") return Infinity;
  if (v === "-Inf") return -Infinity;
  return NaN;
}

function toSignal(data: unknown): number[] | undefined {
  if (Array.isArray(data)) return data.flat(Infinity).map(toNumber);
  if (typeof data === "number" || data === "Inf" || data === "-Inf") {
    return [toNumber(data)];
  }
  return undefined;
}

export async function fetchSignal(
  app: App,
  url: string,
): Promise<number[]> {
  const result = await app.callServerTool({
    name: "uri2json",
    arguments: { uri: url },
  });
  requireSuccess(result, "uri2json");

  // structuredContent has the data without text serialization overhead.
  const sc = result.structuredContent as Record<string, unknown> | undefined;
  const inner = sc?.result as Record<string, unknown> | undefined;
  const fromStructured = toSignal(inner?.data);
  if (fromStructured) return fromStructured;

  // Fallback: parse from content[0].text
  const textEntry =
    result.content?.find((c: { type: string }) => c.type === "text") as
      | { text: string }
      | undefined;
  if (!textEntry?.text) return [];
  const parsed = JSON.parse(textEntry.text);
  return toSignal(parsed?.result?.data) ?? [];
}

// The URL pass I writes to: the original's, with _clean_pass<I> before the
// extension of its last path segment, or at the end if it has none. Never
// the original's own URL, which the first pass would overwrite.
export function passURL(originalURL: string, i: number): string {
  return originalURL.replace(
    /(\.[^./\\]+)?$/,
    (ext) => `_clean_pass${i}${ext}`,
  );
}

export async function runPassChain(
  app: App,
  originalURL: string,
  passes: CleaningPass[],
): Promise<string> {
  let currentURL = originalURL;

  for (let i = 0; i < passes.length; i++) {
    const outURL = passURL(originalURL, i);

    const result = await app.callServerTool({
      name: "cleanSignal",
      arguments: {
        noisyURL: currentURL,
        frequency: passes[i].frequency,
        cleanURL: outURL,
      },
    });
    requireSuccess(result, `Pass ${i + 1} (${passes[i].frequency} Hz)`);

    currentURL = outURL;
  }

  return currentURL;
}
