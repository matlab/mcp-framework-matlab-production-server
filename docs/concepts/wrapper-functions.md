# Wrapper Functions

When a MATLAB function accepts or returns large arrays, passing them as JSON through the LLM wastes tokens and can exceed message limits. Wrapper functions solve this by routing large data through external storage — the LLM passes a URL instead of the data itself.

## The Problem

Consider a function that filters a noisy signal:

```MATLAB
function clean = cleanSignal(noisy, period)
```

The `noisy` input might be 10,000 floating-point samples. Encoding that as JSON text consumes roughly 100,000 tokens. The LLM does not need to see the data — it only needs to tell the tool where the data lives.

## How Wrapper Functions Work

A wrapper function replaces large parameters with URL parameters. It becomes the tool entry point — the LLM calls the wrapper, not your original function:

```
Original:    clean = cleanSignal(noisy, period)
Wrapper:     cleanSignalMCP(noisyURL, period, cleanURL=cleanURL)
```

The wrapper:
1. Reads `noisy` from the file at `noisyURL`
2. Calls your original function: `clean = cleanSignal(noisy, period)`
3. Writes `clean` to the file at `cleanURL` (if provided)

Your original function is unchanged. The wrapper handles all data marshaling.

## Three Transformations

The framework performs three transformations when generating a wrapper:

1. **Large inputs become URL parameters.** The LLM passes a `file:` URI pointing to the data.
2. **Large outputs become URL parameters.** The LLM specifies where to write the result.
3. **Output URLs move to the input argument list.** The LLM must specify output locations when calling the tool.

Scalar parameters (a cutoff frequency, a sample rate) pass through unchanged.

## Automatic Generation

By default (`wrapper="Auto"`), the framework inspects the function parameters and generates a wrapper only when at least one parameter exceeds 64 elements. If all parameters are small, no wrapper is generated and your function serves as the tool entry point directly. The 64-element threshold distinguishes scalars and small vectors (which serialize cheaply as JSON) from arrays that benefit from external storage.

The framework determines which parameters are large by examining argument blocks:
- Arguments declared as `(1,1)` are always scalar — passed directly
- Arguments without a size constraint are assumed large
- Any argument with a declared size whose product exceeds 64 is externalized

The threshold is the `maxLiteralSize` argument of `build`, 64 by default. It applies to the sizes the argument blocks declare, not to the values you pass at run time.

If your function has no argument blocks, Auto cannot determine parameter sizes and skips wrapper generation. The function serves as its own entry point. To get a wrapper, add argument blocks declaring parameter sizes. `wrapper=""`, which always generates one, also needs argument blocks: without them it raises `prodserver:mcp:InputArgBlockRequired`.

```MATLAB
ctf = prodserver.mcp.build("cleanSignal", server="http://localhost:9910");
```

`cleanSignal` declares `noisy` with no size, so it is assumed large. The framework generates `cleanSignalMCP.m` and deploys it as the tool entry point.

**`example` builds no wrapper.** When you pass `example`, the tool description is generated from the example calls and the tool calls your original function directly, so every argument travels by value. Use argument blocks without `example` to get a generated wrapper. `build` raises `prodserver:mcp:ExampleWrapperConflict` if you combine `example` with a `wrapper` other than `"Auto"` or `"None"`.

### Generated Wrapper Structure

```MATLAB
function cleanSignalMCP(noisyURL, period, out)
    arguments (Input)
        noisyURL (1,1) string  % file: URL pointing to input signal
        period (1,1) double    % Period (frequency) of the noise
        out.cleanURL (1,1) string = ""  % file: URL where clean signal is saved
    end

    marshaller = prodserver.mcp.io.MarshallURI();
    noisy = deserialize(marshaller, noisyURL);
    noisy = noisy{1};
    clean = cleanSignal(noisy, period);
    if strlength(out.cleanURL) > 0
        serialize(marshaller, out.cleanURL, {clean});
    end
end
```

## Custom Wrappers

Write your own wrapper when the data source requires logic beyond simple deserialization — for example, reading a CSV file with custom import options, or writing multiple output files.

```MATLAB
function plotTrajectoriesMCP(quakeURL, sampleRate, correction, start, stop, plotURL)
% Generate trajectory plots from 3-axis seismometer data.
    arguments (Input)
        quakeURL string   % file: URL containing a table of accelerations
        sampleRate double % Seismometer sample rate in Hertz
        correction double % Instrument correction factor
        start double      % Start offset in seconds
        stop double       % Stop offset in seconds
        plotURL string    % file: URL to save the plot
    end

    quakeFile = prodserver.mcp.io.uri.File.FileURI2Path(quakeURL);
    qd = readtable(quakeFile);
    plotFile = prodserver.mcp.io.uri.File.FileURI2Path(plotURL);
    plotTrajectories(qd, sampleRate, correction, start, stop, plotFile);
end
```

Pass your custom wrapper to `build`:

```MATLAB
ctf = prodserver.mcp.build("plotTrajectories", ...
    wrapper="plotTrajectoriesMCP.m", ...
    server="http://localhost:9910");
```

The framework uses your wrapper as the tool entry point and generates the tool description from its argument blocks and comments.

## Marshaling Utilities

The `prodserver.mcp.io` namespace provides utilities for reading and writing data at URLs.

### MarshallURI

`prodserver.mcp.io.MarshallURI` is the primary interface for data marshaling:

| Method | Description |
| :--- | :--- |
| `deserialize(marshaller, url)` | Read data from a URL. Returns a cell array. |
| `serialize(marshaller, url, data)` | Write data to a URL. Data is a cell array. |
| `exist(marshaller, url)` | Check whether a URL points to existing data. |

### uri.File

`prodserver.mcp.io.uri.File` implements the `file:` scheme:

| Method | Description |
| :--- | :--- |
| `FileURI2Path(uri)` | Convert a `file:` URI to a filesystem path. |

Use `FileURI2Path` in custom wrappers when you need direct filesystem access (e.g., for `readtable` or `imread`).

## URL Scheme

The framework currently supports the `file:` scheme. URLs follow the standard format, which is also the form the tool descriptions advertise:

```
file:///C:/data/source/signal.mat
file:///tmp/data/signal.mat
file:////server/share/data/output.csv
```

Use four slashes for UNC paths on Windows. The single-slash form, such as `file:/C:/data/source/signal.mat`, is also accepted.

MATLAB Production Server reads and writes these files itself, so a `file:` URL names a path on the server's machine, not the client's. A URL built from a folder on the client, as the example walkthroughs do, works only when the server runs on the same machine, or can reach that folder at the same path, for example on a shared drive. For a remote server, use a folder the server can read and write, such as a share both machines mount at the same path.

A URL whose path contains a `..` segment, or an encoded separator (`%2F`, or `%5C` on Windows), is refused with `prodserver:mcp:BadFilePath`. No file name needs either, and a client could use them to reach a file outside the folder the URL names. `Path2FileURI` resolves `.` and `..` in a local path before it builds the URL, so give it relative paths freely.

## When Wrappers Are Not Needed

If all your parameters are small (scalars, short strings, small vectors), the framework passes them directly as JSON. With the default `wrapper="Auto"`, no wrapper is generated and your original function serves as the tool entry point. This is the common case for functions with simple inputs like `principalStress([120 -50 80], "max")`.

To force wrapper generation regardless of parameter size, pass `wrapper=""` (the function still needs argument blocks). To suppress wrapper generation even when parameters are large, pass `wrapper="None"` — all data passes through the LLM as JSON regardless of size. Use `"None"` only when you know parameters are small, or when an external system (not the LLM) provides the data.

## Effect on Schemas

When a wrapper externalizes a parameter, the tool schema describes the URL — a string — not the underlying data type. For the Periodic Noise example's `cleanSignal`, the LLM sees:

```json
"noisyURL": {
  "type": "string",
  "description": "URL pointing to the input value for 'noisy'. The content of the URL is:
Noisy signal",
  "examples": [ "file:///tmp/storage/data.csv", "file:///c:/tmp/storage/data.csv", "http://server/writable/resource (PUT endpoint)" ]
},
"cleanURL": {
  "type": "string",
  "description": "URL pointing to the output value for 'clean'. This value never returned
inline. Read result from URL using scheme-appropriate method: ...",
  "examples": [ "..." ],
  "writeOnly": true
}
```

An externalized output becomes an optional input marked `writeOnly`: the LLM supplies a URL and the tool writes the result there. The original schemas move to `$defs` in `inputSchema`:

```json
"$defs": {
  "inputSchema":  { "noisyURL": { "type": "array", "items": { "type": "number" }, "description": "Noisy signal" } },
  "outputSchema": { "cleanURL": { "type": "array", "items": { "type": "number" }, "description": "Filtered signal" } }
}
```

The LLM never interacts with the array data directly. It provides a URL, and the wrapper handles the rest. With `encoding="Invertible"`, each URL's description also points to its `$defs` entry, because the data at the URL must be wire-encoded. See [Schemas](./schemas.md#large-data-and-schema-interaction).

## See Also

- [Building MCP Tools — Functions with Large Data](../guides/building-tools.md#functions-with-large-data) — the build workflow for large-data functions
- [Schemas](./schemas.md) — how wrappers change the generated schema
- [Wire Encoding](./wire-encoding.md) — how values are serialized when they do cross the wire
- [Periodic Noise example](../../Examples/Periodic%20Noise/walkthrough.md) — automatic wrapper generation
- [Earthquake example](../../Examples/Earthquake/Earthquake.md) — custom wrapper

--- Copyright 2026 The MathWorks, Inc. ---
