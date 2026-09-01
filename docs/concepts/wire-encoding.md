# Wire Encoding

JSON was designed for web data interchange, not scientific computing. It lacks features that MATLAB numeric code relies on: vector orientation, complex numbers, NaN values, and integer type identity. The MCP Framework wire encoding solves this by wrapping MATLAB values with explicit type and shape metadata.

## The Problem

| MATLAB feature | JSON limitation | Consequence |
| :--- | :--- | :--- |
| Vector orientation | `[1,2,3]` has no shape — `jsondecode` always produces a column | Row vectors become columns; matrix operations give wrong results |
| Complex numbers | No JSON type exists | Cannot represent phasors, FFT output, eigenvalues |
| NaN (missing data) | Not a valid JSON literal | Sensor dropouts become 0; interpolation fits wrong curves |
| Integer types | One `number` type (float64) | `uint8(200)` and `double(200)` are indistinguishable; type-dependent code gives wrong answers |

These are not edge cases. Any function that operates on matrices, processes sensor data, or dispatches on numeric type will produce wrong results if the encoding discards this information.

## The Encoding Format

Every non-scalar MATLAB array is transmitted as a wrapper object with three fields:

```json
{"type": "double", "size": [1, 3], "data": [1, 2, 3]}
```

| Field | Meaning |
| :--- | :--- |
| `type` | MATLAB class name (`double`, `uint8`, `int16`, `logical`, `string`, etc.) |
| `size` | Dimensions in MATLAB convention `[rows, cols, ...]` — always at least 2 elements |
| `data` | Flat array of values in row-major order |

This unambiguously identifies a 1x3 double row vector. No information is lost.

## Encoding Rules

### Bare Values (No Wrapper Needed)

| MATLAB value | JSON |
| :--- | :--- |
| Double scalar | `3.14` |
| Logical scalar | `true` / `false` |
| String or char scalar | `"hello"` |
| NaN | `"NaN"` |
| +Inf / -Inf | `"Inf"` / `"-Inf"` |
| Complex scalar | `{"re": 3.0, "im": -1.5}` |
| Scalar struct | `{"field": value, ...}` |

### Wrapped Values (Arrays)

All arrays — even a 1x3 vector — use the wrapper format. A bare JSON array `[1,2,3]` is always an encoding error.

Additional rules by type:
- **Complex arrays** — add `"im": [...]` parallel to `"data"`
- **String arrays with missing** — use `null` for missing values in `"data"`
- **Struct arrays** — `"data"` contains scalar-struct objects in row-major order
- **Categorical** — add `"categories": [...]` and `"ordinal": true/false`
- **Datetime arrays** — add `"tz": "America/New_York"` (omit for UTC)
- **Tables** — use `"type": "table"` with `"rows"` and `"variables"` fields

### Row-Major Data Order

For a 2x3 matrix `[1 2 3; 4 5 6]`, the data array is `[1,2,3,4,5,6]` — row 1 left-to-right, then row 2. Not column-by-column.

### Scalar Structs Need No Wrapper

A scalar struct transmits as a plain JSON object: `{"name": "Alice", "age": 30}`. Only struct arrays use the `{"type": "struct", "size": ..., "data": [...]}` wrapper.

## Examples

```json
// 3x1 column vector [1;2;3]
{"type": "double", "size": [3, 1], "data": [1, 2, 3]}

// 2x3 matrix [1 2 3; 4 5 6]
{"type": "double", "size": [2, 3], "data": [1, 2, 3, 4, 5, 6]}

// 1x4 logical
{"type": "logical", "size": [1, 4], "data": [true, false, true, true]}

// 2x2 complex matrix
{"type": "double", "size": [2, 2], "data": [1, 3, 5, 7], "im": [2, 4, 6, 8]}

// Signal with NaN dropouts
{"type": "double", "size": [5, 1], "data": [0.5, 0.87, "NaN", "NaN", 0.12]}

// uint8 image (2x3)
{"type": "uint8", "size": [2, 3], "data": [80, 82, 79, 81, 80, 78]}
```

## When Wire Encoding Applies

Wire encoding applies to any parameter whose type or shape would be lost in plain JSON. The framework uses it automatically when:

- The parameter is a non-scalar array (any shape beyond 1x1)
- The output contains complex values, NaN, or specific integer types
- The function dispatches on `class()` — accepting different numeric types at the same position

When you build with Invertible encoding, the framework includes a wire-encoding resource at `mcp://protocol/tools/wire-format/parameters/encoding_rules`. LLMs read this resource to learn the encoding rules before calling tools that require them. Servers that use only JSON encoding don't include this resource.

## Why Not Nested JSON Arrays?

An LLM could theoretically use `[[1,2,3]]` (row) vs `[[1],[2],[3]]` (column). In practice:

1. LLMs produce flat `[1,2,3]` regardless of intended orientation
2. The MATLAB `jsondecode('[1,2,3]')` function always returns a 3x1 column
3. `jsonencode([1,2,3])` and `jsonencode([1;2;3])` both produce `[1,2,3]` — orientation lost in both directions
4. The JSON Schema `"type": "array"` keyword cannot distinguish row from column

## Why Not Argument Coercion?

The MATLAB `arguments` block can coerce type and shape:

```MATLAB
    arguments
        x (1,:) double   % forces row vector
    end
```

This works only when the function always expects one specific type or shape. It fails when:
- Both orientations are valid inputs (matrix multiplication)
- The function dispatches on type (sensor fusion accepting `uint8`, `uint16`, or `double`)
- The data contains values unrepresentable in JSON regardless of coercion (NaN, complex)

## Decoding Order

When decoding a JSON value back to MATLAB, apply these rules in order:

1. `null` → error (only valid inside string/categorical data arrays)
2. Boolean → logical scalar
3. Number → double scalar
4. `"NaN"` / `"Inf"` / `"-Inf"` → double special value
5. ISO 8601 string → datetime scalar (otherwise char row vector)
6. Object with `"type"` field → dispatch on type discriminator table
7. Object with `"re"` and `"im"` → complex double scalar
8. Object without `"type"` → scalar struct
9. JSON array → error (never produced by this encoding)

## See Also

- [Schemas](./schemas.md) — how schemas describe the expected encoding
- [Wrapper Functions](./wrapper-functions.md) — when large data bypasses wire encoding entirely
- [Wire Encoding example](../../Examples/WireEncoding/WireEncoding.md) — five tools demonstrating each encoding need
- [Building MCP Tools](../guides/building-tools.md) — the build-deploy workflow

--- Copyright 2026 The MathWorks, Inc. ---
