# Removing Periodic Noise

Build an MCP tool that removes periodic noise from a signal. This example demonstrates how the framework **auto-generates** a wrapper function when parameters are large — routing array data through file storage instead of JSON.

## The Function

`cleanSignal` accepts a noisy signal vector and a noise frequency, and returns the filtered signal:

```MATLAB
function clean = cleanSignal(noisy, period)
    arguments (Input)
        noisy double         % Noisy signal
        period (1,1) double  % Frequency of the noise to remove
    end
    arguments (Output)
        clean double         % Filtered signal
    end
    ...
end
```

## Why a Wrapper?

The `noisy` input might be 10,000 samples. Encoding that as JSON consumes ~100,000 tokens. The LLM doesn't need to see the data — it only needs to tell the tool *where* the data lives.

The framework detects this automatically: `noisy double` has no size constraint, so it is assumed large. `period (1,1) double` is scalar, so it passes directly. The framework generates a wrapper that replaces large parameters with file URLs.

## Build

The framework inspects argument blocks and auto-generates the wrapper. Since argument blocks fully specify the types, no `example` is needed either:

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("cleanSignal", server="http://localhost:9910");
```

The default `wrapper="Auto"` triggers generation because `noisy` has no size constraint (assumed large, exceeds the 64-element threshold).

## The Generated Wrapper

The framework produces `cleanSignalMCP.m` automatically:

```MATLAB
function cleanSignalMCP(noisyURL, period, out)
    arguments (Input)
        noisyURL (1,1) string  % file: URL pointing to input signal
        period (1,1) double    % Frequency of the noise to remove
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

The externalized output `cleanURL` is an optional name-value parameter — the LLM provides a writable URL to receive the result. The wrapper reads input data from the URL, calls `cleanSignal`, and writes output to the specified location.

## Verify

```MATLAB
prodserver.mcp.ping(endpoint)
ans =
    true

prodserver.mcp.exist(endpoint, "cleanSignal", "Tool")
ans =
    true
```

## Test with MCP Protocol

Call the tool using file URLs, just as an LLM would:

```MATLAB
noisyURL = "file:" + fullfile(pwd, "openloopVoltage.csv");
cleanURL = "file:" + fullfile(pwd, "cleanOpenLoop.csv");

prodserver.mcp.call(endpoint, "cleanSignal", noisyURL, 60, cleanURL=cleanURL)
```

## Connect an MCP Client

```json
{
  "mcpServers": {
    "cleanSignal": {
      "url": "http://localhost:9910/cleanSignal/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Remove the 60 Hz periodic noise from the signal in openloopVoltage.csv in my working directory. Save the result as openloopVoltage_clean.csv.

The LLM reads the tool description, constructs file URLs for the input and output, and calls `cleanSignal` with the noise frequency.

--- Copyright 2025-2026 The MathWorks, Inc. ---
