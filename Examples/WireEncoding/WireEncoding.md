# Wire Encoding for Numeric Data

This example demonstrates why the MCP Framework wire encoding format is essential for MATLAB numeric computing. It hosts five engineering tools that produce **wrong answers** when plain JSON is used for data transport, along with ten MCP resources containing realistic sensor and engineering data.

An LLM connected to this server can read sensor data from resources and call the tools — but only if the wire encoding format is used to preserve vector orientation, complex numbers, NaN values, and integer types.

| Tool | Function | Wire Encoding Need |
| :--- | :--- | :--- |
| matrixMultiply | Multiply two matrices or vectors | Both orientations are valid inputs — `(:,:)` cannot coerce to a fixed shape, and JSON `[1,2,3]` always arrives as a column |
| analyzeACCircuit | Series RLC impedance/current across a frequency sweep | Outputs are inherently complex-valued phasors; JSON has no complex number type |
| interpolateWithMissing | Bridge sensor dropout gaps via interpolation | Signal contains NaN marking missing samples; JSON has no NaN literal, so gaps become 0 and the interpolation fits a wrong curve |
| fuseSensors | Precision-weighted optimal fusion of two sensors | Dispatches on `class()` to derive quantization noise from ADC bit depth; JSON erases integer types so both sensors get equal weight |
| blendImages | Alpha-blend two images with type-dependent arithmetic | Dispatches on `class()` for saturation semantics (uint8) vs signed (int16) vs HDR (double); JSON collapses all to double |

## The Problem

JSON was designed for web data interchange, not scientific computing. It has fundamental limitations when representing MATLAB numeric data:

| MATLAB Feature | JSON Limitation | Consequence |
| :--- | :--- | :--- |
| Vector orientation | `[1,2,3]` has no shape — `jsondecode` always produces a column | Row vectors become columns; dimension errors or wrong products |
| Complex numbers | No JSON type exists | Cannot represent AC phasors, FFT output, eigenvalues |
| NaN (missing data) | Not a valid JSON literal | Sensor dropout becomes `null` or 0; interpolation fits wrong curve |
| Integer types | One `number` type (float64) | `uint8(200)` and `double(200)` are indistinguishable; type-dependent arithmetic gives wrong values |

The wire encoding solves all of these by wrapping values with explicit type and shape metadata:

```json
{"type":"double", "size":[1,3], "data":[1,2,3]}
```

This is unambiguously a 1x3 row vector of doubles — orientation, type, and shape are all preserved.

## Why Not Nested JSON Arrays?

An LLM could theoretically use `[[1,2,3]]` (row) vs `[[1],[2],[3]]` (column). In practice:

1. **LLMs don't do this.** Asked to encode "the row vector [1,2,3]", every major LLM produces `[1,2,3]` — a flat array with no orientation.
2. **MATLAB's `jsondecode('[1,2,3]')` returns a 3x1 column vector** regardless of intent.
3. **`jsonencode([1,2,3])` and `jsonencode([1;2;3])` both produce `[1,2,3]`** — orientation is destroyed in both directions.
4. **No schema enforcement** — JSON Schema's `"type":"array"` cannot distinguish row from column.

For complex numbers, NaN, and integer types, there is no workaround at all.

## Why Not Argument Coercion?

MATLAB's `arguments` block can coerce type and shape:
```matlab
arguments
    x (1,:) double   % forces row vector
    y int8           % forces int8
end
```

This eliminates the wire-encoding need **only when the function always expects one specific type or shape**. It fails when:
- Both orientations are valid inputs (`matrixMultiply`)
- The function dispatches on type — accepting `uint8`, `uint16`, or `double` on the same parameter (`fuseSensors`, `blendImages`)
- The data contains values unrepresentable in JSON regardless of coercion (`NaN`, complex)

## The Five Tools

Each tool demonstrates a different wire-encoding requirement.

### 1. matrixMultiply — Vector/Matrix Orientation

Multiplies two matrices or vectors. The result depends entirely on orientation:

| A | B | A * B | Result |
| :--- | :--- | :--- | :--- |
| 1x3 row | 3x1 column | (1x3) * (3x1) | Scalar (dot product) |
| 3x1 column | 1x3 row | (3x1) * (1x3) | 3x3 matrix (outer product) |
| 3x3 matrix | 3x1 column | (3x3) * (3x1) | 3x1 vector |

**Without wire encoding:** An LLM sends `"A": [1,2,3]` and `"B": [4,5,6]`. Both arrive as 3x1 columns via `jsondecode`. The multiplication (3x1)*(3x1) is a **dimension error** — it doesn't just give the wrong answer, it fails entirely.

**With wire encoding:**
```json
{
  "A": {"type":"double", "size":[1,3], "data":[1,2,3]},
  "B": {"type":"double", "size":[3,1], "data":[4,5,6]}
}
```
Result: scalar 32 (dot product). Unambiguous.

The function declares `A (:,:) double` — it **cannot** coerce to a fixed orientation because both orientations are semantically meaningful inputs.

### 2. analyzeACCircuit — Complex Numbers

Analyzes a series RLC circuit across a frequency sweep, computing complex impedance, current, and component voltages at each frequency. This is the standard engineering workflow for characterizing filters, crossover networks, and EMI suppression circuits (Bode plot analysis).

For an audio crossover network (R=8 Ohm, L=1.2 mH, C=22 uF, Vs=10 V) swept from 100 Hz to 22 kHz, the output is a vector of 20 complex impedances, 20 complex currents, and 60 complex voltages (20 per component).

**Without wire encoding:** These results **cannot be transmitted**. JSON has no complex number type. There is no workaround — `8 - 72.3j` is simply not representable as a JSON value. An entire frequency sweep of 100 complex values has zero JSON representation.

**With wire encoding:**
```json
{
  "Z_total": {"type":"double", "mwcomplex":true, "size":[20,1], "data":[[8,-72.3],[8,-46.1],...]}
}
```

The inputs are all real (R, L, C, frequency vector, voltage), so they work fine as plain JSON. The problem is exclusively on the **output** side — this function produces complex-valued results that JSON cannot carry.

### 3. interpolateWithMissing — NaN Preservation

Interpolates a sensor signal that contains NaN values marking dropout periods.

**Sample scenario:** An industrial vibration sensor monitoring a rotary compressor at 1 kHz sample rate. RF interference causes wireless packet loss, resulting in NaN bursts at 10 positions across 100 samples.

**Without wire encoding:** NaN is not valid JSON. If converted to `null` and then decoded as 0, the interpolation fits through zero at dropout positions. For a vibration signal oscillating between -1 and +1, inserting zeros in the middle of a swing dramatically distorts the reconstructed waveform — the interpolation curve dips to zero instead of smoothly bridging the gap.

**With wire encoding:**
```json
{
  "signal": {
    "type": "double",
    "size": [100,1],
    "data": [0.0, 0.548, 0.871, ..., "NaN", "NaN", "NaN", ..., 0.004]
  }
}
```

NaN is encoded as the string `"NaN"`, preserving its identity as missing data distinct from zero.

### 4. fuseSensors — Integer Type Dispatch (Heterogeneous)

Optimally fuses two sensor readings by weighting inversely to quantization noise. The noise level is derived from each sensor's numeric type:
- `uint8` (8-bit ADC): quantization noise ~ 0.2% of range
- `uint16` (16-bit ADC): quantization noise ~ 0.0008% of range
- `double` (analog/float): quantization noise ~ 0%

**Sample scenario:** A laser rangefinder (double, sub-mm precision) and an ultrasonic sensor (uint16, 1mm resolution in millimeters) both measure distance to the same target at ~2.45 m. The laser reading `2.4503` (double) should be trusted almost entirely over the ultrasonic reading `2451` (uint16 in mm).

**Without wire encoding:** Both sensors arrive as `double`. The function calls `class(sensor1)` which returns `'double'` for both. The quantization noise is `eps` (~2e-16) for both. The fusion gives **equal 50/50 weight** regardless of actual sensor precision — averaging 2.4503 with 2451.0 to produce ~1226.7, an obviously wrong answer.

**With wire encoding:**
```json
{
  "sensor1": {"type":"double", "size":[1,30], "data":[2.4503, 2.4498, ...]},
  "sensor2": {"type":"uint16", "size":[1,30], "data":[2451, 2448, ...]}
}
```

The function correctly assigns near-100% weight to the laser (double = essentially zero quantization noise) and near-0% to the ultrasonic sensor. The fused result is ~2.4501 meters — correct.

Note: declaring `sensor1 uint8` in the arguments block would force a single type via coercion. But this function must accept **different types on the same parameter** to compare their precisions. There is no fixed-type declaration that works.

### 5. blendImages — Integer Type Dispatch (Saturation)

Alpha-blends two images with type-dependent arithmetic:
- `uint8`: 8-bit pixels [0, 255], saturating arithmetic
- `int16`: signed 16-bit, supports negative values (difference/gradient images)
- `double`: HDR, no clamping, values may exceed [0, 1]

Typical use case: temporal noise reduction on thermal sensor arrays. The FLIR Lepton and Panasonic Grid-EYE AMG8833 are common low-cost thermal cameras that output 8-bit pixel data. Averaging consecutive frames reduces thermal noise while preserving the uint8 output type needed by downstream threshold-based occupancy detection.

**Without wire encoding:** `class(A)` returns `'double'`, always selecting the HDR code path. For uint8 thermal frames, this means:
- Output type is `double` instead of `uint8`
- No saturation clamping to [0, 255]
- Downstream threshold comparison `result > uint8(100)` fails on double data

**With wire encoding:**
```json
{
  "A": {"type":"uint8", "size":[12,10], "data":[80, 82, 79, ...]},
  "B": {"type":"uint8", "size":[12,10], "data":[81, 80, 78, ...]},
  "alpha": 0.6
}
```

The function correctly selects uint8 blending, producing `uint8` output clamped to [0, 255].

As with `fuseSensors`, the function must accept multiple types on the same parameter. Coercion to a fixed type would eliminate the type-dependent behavior that is the tool's purpose.

## Data Resources

The server includes ten MCP resources containing realistic sensor and engineering data. An LLM reads these resources to obtain input data, then calls the appropriate tool with wire-encoded arguments.

The CSV data files live in `Test/data/examples/WireEncoding/` and are shared between the example build script and the test suite (unit and integration tests).

| Resource URI | Description | Tool |
| :--- | :--- | :--- |
| `mcp://wire-encoding/data/audio-crossover` | 20 frequencies for loudspeaker crossover analysis | analyzeACCircuit |
| `mcp://wire-encoding/data/emi-filter` | 15 mains-harmonic frequencies for EMI filter analysis | analyzeACCircuit |
| `mcp://wire-encoding/data/vibration-sensor` | 100 vibration samples with NaN dropout bursts | interpolateWithMissing |
| `mcp://wire-encoding/data/temperature-logger` | 48 hourly temperature readings with NaN comm failures | interpolateWithMissing |
| `mcp://wire-encoding/data/pressure-sensors` | 100 readings from redundant 8-bit and 16-bit pressure ADCs | fuseSensors |
| `mcp://wire-encoding/data/rangefinder` | 30 readings from laser (double) and ultrasonic (uint16) sensors | fuseSensors |
| `mcp://wire-encoding/data/thermal-frame-A` | 12x10 uint8 thermal image (person in doorway) | blendImages |
| `mcp://wire-encoding/data/thermal-frame-B` | 12x10 uint8 thermal image (same scene, 100 ms later) | blendImages |
| `mcp://wire-encoding/data/gradient-frame-A` | 12x10 int16 horizontal edge detection output | blendImages |
| `mcp://wire-encoding/data/gradient-frame-B` | 12x10 int16 edge detection (100 ms later) | blendImages |

## Example Prompts

These are the kinds of natural-language prompts a user would give an LLM connected to this server:

| Prompt | LLM reads | LLM calls |
| :--- | :--- | :--- |
| "Compute the dot product of [1,2,3] and [4,5,6]" | — | matrixMultiply with 1x3 and 3x1 |
| "What's the outer product of [2,3,4] and [10,20,30]?" | — | matrixMultiply with 3x1 and 1x3 |
| "Analyze the audio crossover filter across its frequency range" | audio-crossover resource | analyzeACCircuit |
| "How does the EMI filter perform at mains harmonics?" | emi-filter resource | analyzeACCircuit |
| "Reconstruct the vibration signal from the sensor with dropouts" | vibration-sensor resource | interpolateWithMissing |
| "Fill in the missing temperature readings" | temperature-logger resource | interpolateWithMissing |
| "Fuse the pressure transducer readings" | pressure-sensors resource | fuseSensors |
| "Fuse the sensor readings from the laser and ultrasonic range finder" | rangefinder resource | fuseSensors |
| "Average the two thermal camera frames to reduce noise" | thermal-frame-A, thermal-frame-B | blendImages |
| "Smooth the gradient frames for stable edge detection" | gradient-frame-A, gradient-frame-B | blendImages |

## Build and Deploy

### Using buildWireEncodingServer (programmatic)

```MATLAB
% Build only (no deployment)
ctf = buildWireEncodingServer();

% Build and deploy to localhost:9910
[ctf, endpoint] = buildWireEncodingServer(host="localhost");

% Build and deploy to a specific host and port
[ctf, endpoint] = buildWireEncodingServer(host="myserver", port=9920);
```

### Using /mps-mcp-build (AI agentic skill)

From Claude Code, invoke the build skill:

```
/mps-mcp-build Examples/WireEncoding/matrixMultiply.m Examples/WireEncoding/analyzeACCircuit.m Examples/WireEncoding/interpolateWithMissing.m Examples/WireEncoding/fuseSensors.m Examples/WireEncoding/blendImages.m localhost:9910
```

The skill handles building, deploying, and registering the MCP server with your client.

### Manual step-by-step

```MATLAB
cd Examples/WireEncoding

fcn = ["matrixMultiply", "analyzeACCircuit", "interpolateWithMissing", ...
       "fuseSensors", "blendImages"];

ctf = prodserver.mcp.build(fcn, ...
    archive="WireEncoding", ...
    wrapper=["None","None","None","None","None"], ...
    resource=resources, ...
    folder="./deploy");

endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

See `buildWireEncodingServer.m` for the complete resource definitions.

## Demo: Calling the Tools

After deployment, exercise each tool with `prodserver.mcp.call`. See also `WireEncodingDemo.m` for an interactive Live Script version.

```MATLAB
endpoint = "http://localhost:9910/WireEncoding/mcp";

% 1. Matrix multiply: dot product (1x3 * 3x1 -> scalar)
C = prodserver.mcp.call(endpoint, "matrixMultiply", [1 2 3], [4;5;6])
% C = 32

% 2. Matrix multiply: outer product (3x1 * 1x3 -> 3x3)
C = prodserver.mcp.call(endpoint, "matrixMultiply", [4;5;6], [1 2 3])
% C = [4 8 12; 5 10 15; 6 12 18]

% 3. AC circuit frequency sweep (20 frequencies)
freq = logspace(2, 4.3, 20)';
[Z_total, I_total, V_R, V_L, V_C] = prodserver.mcp.call(endpoint, ...
    "analyzeACCircuit", 8, 1.2e-3, 22e-6, freq, 10)
% Z_total is 20x1 complex vector
% I_total is 20x1 complex vector

% 4. Interpolate vibration signal with dropouts
% Data files are in Test/data/examples/WireEncoding/ (relative to project root)
dataDir = fullfile(fileparts(which("buildWireEncodingServer")), "..", "..", ...
    "Test", "data", "examples", "WireEncoding");
data = readtable(fullfile(dataDir, "vibration_sensor.csv"), "CommentStyle", "#");
[reconstructed, gapMask] = prodserver.mcp.call(endpoint, ...
    "interpolateWithMissing", data.time_s, data.acceleration_g, data.time_s)
% reconstructed has no NaN — gaps are smoothly bridged

% 5. Fuse laser and ultrasonic rangefinder
data = readtable(fullfile(dataDir, "rangefinder_sensors.csv"), "CommentStyle", "#");
[fused, weights, uncertainty] = prodserver.mcp.call(endpoint, ...
    "fuseSensors", data.laser_m, uint16(data.ultrasonic_mm_uint16))
% weights ≈ [1.0, 0.0] — trusts laser almost entirely

% 6. Blend thermal frames for noise reduction
A = uint8(readmatrix(fullfile(dataDir, "thermal_frame_A.csv"), "CommentStyle", "#"));
B = uint8(readmatrix(fullfile(dataDir, "thermal_frame_B.csv"), "CommentStyle", "#"));
result = prodserver.mcp.call(endpoint, "blendImages", A, B, 0.6)
% result is uint8, 12x10, noise-reduced thermal image
```

## Wire Encoding Reference

Every MCP Framework server automatically exposes the wire encoding specification as an MCP resource:

```
mcp://protocol/tools/wire-format/parameters/encoding_rules
```

LLMs read this resource to learn the encoding rules. The key rules are:
- Arrays are **never** bare `[1,2,3]` — always wrapped with `type`, `size`, `data`
- `size` preserves orientation: `[1,3]` for row, `[3,1]` for column
- Data is **row-major** (last index varies fastest)
- Complex values use `"mwcomplex":true` with `[real, imag]` pairs
- NaN, Inf, -Inf are encoded as strings: `"NaN"`, `"Inf"`, `"-Inf"`
- Integer types are explicit: `"type":"uint8"`, `"type":"int16"`, etc.

## Tool Reference

### matrixMultiply

| Parameter | Type | Shape | Description |
| :--- | :--- | :--- | :--- |
| A | double | (:,:) | Left operand — any 2D shape |
| B | double | (:,:) | Right operand — inner dimensions must match A |

**Returns:** C (double, shape determined by inputs)

### analyzeACCircuit

| Parameter | Type | Shape | Description |
| :--- | :--- | :--- | :--- |
| R | double | (1,1) | Resistance (Ohm) |
| L | double | (1,1) | Inductance (H) |
| C | double | (1,1) | Capacitance (F) |
| frequency | double | (:,1) | Frequency sweep vector (Hz) |
| Vsource | double | (1,1) | Source voltage amplitude (V) |

**Returns:** Z_total, I_total, V_R, V_L, V_C (all complex double column vectors, one value per frequency)

### interpolateWithMissing

| Parameter | Type | Shape | Description |
| :--- | :--- | :--- | :--- |
| t | double | (:,1) | Sample timestamps |
| signal | double | (:,1) | Signal with NaN at dropouts |
| t_query | double | (:,1) | Times to interpolate at |
| method | string | (1,1) | "linear", "pchip", "spline", or "makima" (default: "pchip") |

**Returns:** reconstructed (double column), gapMask (logical column — true where query falls in original gap)

### fuseSensors

| Parameter | Type | Shape | Description |
| :--- | :--- | :--- | :--- |
| sensor1 | numeric | any | Readings from sensor 1 — type encodes ADC resolution |
| sensor2 | numeric | any | Readings from sensor 2 — may be different type |

**Returns:** fused (double, normalized 0-1), weights (1x2 double), uncertainty (scalar double)

### blendImages

| Parameter | Type | Shape | Description |
| :--- | :--- | :--- | :--- |
| A | numeric | (:,:) | Image A — uint8, int16, or double |
| B | numeric | (:,:) | Image B — same type as A |
| alpha | double | (1,1) | Blending factor in [0, 1] |

**Returns:** result (same type as A — uint8, int16, or double)

--- Copyright 2026 The MathWorks, Inc. ---
