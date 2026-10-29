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
| `type` | MATLAB class name (`double`, `uint8`, `int16`, `logical`, `string`, etc.). A parameter's schema says which: see below. |
| `size` | Dimensions in MATLAB convention `[rows, cols, ...]` — always at least 2 elements |
| `data` | Flat array of values in row-major order |

This unambiguously identifies a 1x3 double row vector. No information is lost.

A parameter's schema limits `type` to the classes that make sense for it, as a JSON Schema `enum` of one or more class names, such as `{"enum": ["double"]}`. An input accepts the classes MATLAB converts to the parameter's declared class: any numeric class or `logical` for a numeric or logical parameter (`true + true` is 2), and `char` or `string` for a `string` parameter. A `char` parameter takes only `char`, since a string array can be ragged and a char array can't; `struct` and `cell` are exact. An output's `type` is exactly the class the tool returns, as its `arguments (Output)` block declares. A parameter with no declared class takes its classes from its validators (`mustBeNumeric` gives the numeric classes, `mustBeFloat` gives `double` and `single`, `mustBeText` gives `char`, `string` and `cell`, and so on; several give the classes they all allow), else from the example calls, and with none observed, every class the encoding carries. The encoding rules tell the LLM to use the parameter's own class when it knows it: for ordinary numbers, that is `double`.

### Published Schemas

Under `encoding="Invertible"`, a parameter that may hold a scalar is published as an `anyOf` of its bare forms (below) and the wrapper, for inputs and outputs alike. That is a parameter declared `(1,1)`, one whose size allows a single element, such as `(1,:)`, or one with no declared size. A numeric parameter's bare forms include the strings `"NaN"`, `"Inf"` and `"-Inf"`. A fixed size of more than one element keeps the wrapper alone.

```json
// A (1,1) double output
{
  "description": "Gain",
  "anyOf": [
    {"type": "number"},
    {"type": "string", "enum": ["NaN", "Inf", "-Inf"]},
    {"type": "object", "required": ["type", "size", "data"], "properties": {
      "type": {"enum": ["double"]},
      "size": {"type": "array", "items": {"type": "number"}, "minItems": 2},
      "data": {"type": "array", "minItems": 1, "maxItems": 1, "items": {"anyOf": [
        {"type": "number"}, {"type": "string", "enum": ["NaN", "Inf", "-Inf"]}]}}
    }}
  ]
}
```

It is `anyOf`, not `oneOf`, because a scalar struct's bare form and the wrapper are both objects. The description, annotation and `x-call-by` stay at the top level, not inside the alternatives. The wrapper's `data` is always an array, even for a scalar: a scalar's has exactly one element (`"minItems": 1, "maxItems": 1`). Under `encoding="JSON"` there is no wrapper, and none of this applies.

## Encoding Rules

### Bare Values (No Wrapper Needed)

| MATLAB value | JSON |
| :--- | :--- |
| Numeric scalar, any class | `3.14` |
| Logical scalar | `true` / `false` |
| Char row vector | `"hello"` |
| String scalar | `{"type": "string", "size": [1, 1], "data": ["hello"]}` (wrapped; a bare `"hello"` is accepted for a `string` input) |
| NaN | `"NaN"` |
| +Inf / -Inf | `"Inf"` / `"-Inf"` |
| NaT | `"NaT"` |
| Complex scalar | `{"re": 3.0, "im": -1.5}` |
| Scalar struct | `{"field": value, ...}` |
| Scalar datetime, UTC or unzoned | `"2024-03-15T09:30:00.000Z"` (ISO 8601) |
| Scalar duration | `{"type": "duration", "seconds": 5400}` |

### Wrapped Values (Arrays)

All arrays — even a 1x3 vector — use the wrapper format. A bare JSON array `[1,2,3]` is always an encoding error.

Additional rules by type:
- **Complex arrays** — add `"im": [...]` parallel to `"data"`
- **String arrays with missing** — use `null` for missing values in `"data"`
- **Char matrices** — a char array with more than one row uses `"type": "char"`, and `"data"` holds the individual characters in row-major order. A char row vector is a bare string, unless the text would decode as something else: a date-time, or `"NaN"`, `"Inf"`, `"-Inf"` or `"NaT"`. Then it is wrapped like a char matrix, so it comes back as text.
- **Struct arrays** — `"data"` contains scalar-struct objects in row-major order
- **Cell arrays** — `"type": "cell"`, and `"data"` holds each element encoded by these same rules
- **Categorical** — add `"categories": [...]` and `"ordinal": true/false`
- **Datetime arrays** — `"data"` holds ISO 8601 strings, and `"NaT"` for NaT elements. For a time zone, add `"tz": "America/New_York"` and give each string its offset. Omit `"tz"` for UTC, whose strings end in `Z`, and for unzoned values, whose strings have no suffix. A scalar datetime in a named zone is wrapped the same way, with size `[1, 1]`, so that the zone survives.
- **Duration arrays** — `"data"` holds the values in seconds
- **Tables** — use `"type": "table"` with `"rows"` and `"variables"` fields, and `"rowNames"` if the table has row names
- **Timetables** — use `"type": "timetable"` with `"rows"`, `"rowTimes"` (an encoded datetime or duration), `"timeName"` (the name of the row-times dimension) and `"variables"`

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

Wire encoding is off by default. `build` uses `encoding="JSON"`, which sends plain JSON values. To use wire encoding, request it with the `encoding` argument of `build`: `"Invertible"` applies to every tool, or give one value per tool.

```MATLAB
ctf = prodserver.mcp.build("analyzeACCircuit", encoding="Invertible");
```

Request it for a tool whose parameters would lose their type or shape in plain JSON:

- A parameter is a non-scalar array (any shape beyond 1x1)
- The output contains complex values, NaN, or specific integer types
- The function dispatches on `class()` — accepting different numeric types at the same position
- A parameter is a `categorical`, `table` or `timetable`. Plain JSON can't carry these, so `build` requires Invertible encoding for them.

Plain JSON does carry `datetime` and `duration` parameters, as ISO 8601 text and as seconds: see [Dates and Durations](./schemas.md#dates-and-durations). Invertible encoding keeps more: a datetime's time zone name, not just its offset. Neither encoding keeps a datetime's display format.

`build` can only refuse what it can see: a declared class, or a value in an example call. A timetable can still reach a JSON tool's output at run time, such as in an output with no declared class, in a struct field, or in a cell. JSON sends it as a table whose first column is its row times. Datetimes and durations reaching an output that way are converted as usual.

When at least one tool uses Invertible encoding, the framework includes a wire-encoding resource at `mcp://protocol/tools/wire-format/parameters/encoding_rules`. LLMs read this resource to learn the encoding rules before calling tools that require them. Other servers don't include it.

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
5. `"NaT"` → datetime `NaT`
6. ISO 8601 string → datetime scalar (otherwise char row vector)
7. Object with `"type"` field → dispatch on type discriminator table
8. Object with `"re"` and `"im"` → complex double scalar
9. Object without `"type"` → scalar struct
10. JSON array → error (never produced by this encoding)

## See Also

- [Schemas](./schemas.md) — how schemas describe the expected encoding
- [Wrapper Functions](./wrapper-functions.md) — when large data bypasses wire encoding entirely
- [Wire Encoding example](../../Examples/WireEncoding/WireEncoding.md) — five tools demonstrating each encoding need
- [Building MCP Tools](../guides/building-tools.md) — the build-deploy workflow

--- Copyright 2026 The MathWorks, Inc. ---
