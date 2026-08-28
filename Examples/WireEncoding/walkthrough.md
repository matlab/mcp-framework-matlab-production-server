# Wire Encoding for Numeric Data

Build a five-tool MCP server that demonstrates why plain JSON fails for MATLAB numeric computing and how the framework's wire encoding preserves vector orientation, complex numbers, NaN values, and integer types.

## The Problem

JSON cannot faithfully represent MATLAB numeric data:

| MATLAB Feature | JSON Limitation |
| :--- | :--- |
| Vector orientation | `[1,2,3]` has no shape — `jsondecode` always produces a column |
| Complex numbers | No JSON type exists |
| NaN (missing data) | Not a valid JSON literal |
| Integer types | One `number` type (float64) erases `uint8` vs `double` |

The wire encoding solves this by wrapping values with type and shape metadata:
```json
{"type":"double", "size":[1,3], "data":[1,2,3]}
```

## The Tools

| Tool | Wire Encoding Need |
| :--- | :--- |
| matrixMultiply | Both orientations are valid inputs |
| analyzeACCircuit | Outputs are complex-valued phasors |
| interpolateWithMissing | Signal contains NaN marking dropout |
| fuseSensors | Dispatches on `class()` for precision weighting |
| blendImages | Dispatches on `class()` for saturation semantics |

## Build and Deploy

```MATLAB
[ctf, endpoint] = buildWireEncodingServer(host="localhost");
```

Or manually:
```MATLAB
fcn = ["matrixMultiply", "analyzeACCircuit", "interpolateWithMissing", ...
       "fuseSensors", "blendImages"];
ctf = prodserver.mcp.build(fcn, archive="WireEncoding", ...
    wrapper=["None","None","None","None","None"], ...
    resource=resources, folder="./deploy");
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

## Verify

```MATLAB
prodserver.mcp.ping(endpoint)
tools = prodserver.mcp.list(endpoint, "Tool");
{tools.name}'
```

## Test with MCP Protocol

Dot product (1x3 row * 3x1 column = scalar):
```MATLAB
C = prodserver.mcp.call(endpoint, "matrixMultiply", [1 2 3], [4;5;6])
C =
    32
```

Outer product (3x1 column * 1x3 row = 3x3 matrix):
```MATLAB
C = prodserver.mcp.call(endpoint, "matrixMultiply", [4;5;6], [1 2 3])
C =
     4     8    12
     5    10    15
     6    12    18
```

AC circuit frequency sweep (complex-valued output):
```MATLAB
freq = logspace(2, 4.3, 20)';
[Z, I, V_R, V_L, V_C] = prodserver.mcp.call(endpoint, ...
    "analyzeACCircuit", 8, 1.2e-3, 22e-6, freq, 10);
```

## Connect an MCP Client

```json
{
  "mcpServers": {
    "WireEncoding": {
      "url": "http://localhost:9910/WireEncoding/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Compute the dot product of [1, 2, 3] and [4, 5, 6].

> Analyze the audio crossover filter (R=8 Ohm, L=1.2 mH, C=22 uF, Vs=10 V) across a frequency sweep from 100 Hz to 22 kHz.

> Fuse the laser and ultrasonic rangefinder readings from the rangefinder resource.

The LLM reads the wire encoding resource to learn how to format numeric data, then calls the tools with properly encoded arguments.

--- Copyright 2026 The MathWorks, Inc. ---
