# Schema Format Reference

Detailed reference for the `%#schema` pragma and JSON Schema patterns used by MCP Framework. For conceptual background on why schemas are needed and how they are generated, see [Schemas](../concepts/schemas.md).

## The `%#schema` Pragma

Place `%#schema` on any line of the comment block above a parameter declaration. If the block has more than one `%#schema` line, the last one overrides the others, except that the first line holding inline JSON (a line containing `{`) ends the search: it wins over any `%#schema` lines below it. MCP Framework supports three syntax forms:

### Replace Mode (`=`)

Completely replaces any auto-generated schema with the user-supplied schema.

```MATLAB
% Beam specification with material and geometry.
%#schema =beam_spec.json
beam_spec (1,1) struct
```

Use replace mode when the schema fully describes the parameter and you do not want MCP Framework to add anything (such as `maxItems` or array wrappers).

### Additive Mode (`+`)

Merges the user schema with the auto-generated schema. User-supplied properties overwrite auto-generated ones where they conflict.

```MATLAB
% A vector of circles with known maximum length.
%#schema +circle.json
circles (1,17) struct
```

Use additive mode when you want MCP Framework to auto-generate container-level properties (like `minItems` and `maxItems` from the fixed dimension `17`) but supply the item-level schema yourself.

### Inline JSON

Provide a JSON Schema fragment directly in the comment:

```MATLAB
% Coordinates of the target.
%#schema { "type": "object", "properties": { "x": {"type": "number"}, "y": {"type": "number"} } }
target (1,1) struct
```

Use inline JSON for simple schemas where a separate file would be overhead. Without a prefix, inline JSON uses **additive** merge (same as `+`). To completely replace the auto-generated schema with inline JSON, use `=`:

```MATLAB
%#schema ={ "type": "object", "properties": { "x": {"type": "number"}, "y": {"type": "number"} } }
```

## JSON Schema Patterns

Schemas follow the [JSON Schema](https://json-schema.org/understanding-json-schema/) vocabulary. The following patterns are most common for MATLAB struct parameters:

### Flat Object (one level)

```json
{
    "type": "object",
    "properties": {
        "temperature": { "type": "number", "description": "Temperature in Celsius" },
        "pressure": { "type": "number", "description": "Pressure in Pascals" }
    }
}
```

### Nested Object (two levels)

```json
{
    "type": "object",
    "properties": {
        "material": {
            "type": "object",
            "description": "Material properties",
            "properties": {
                "youngs_modulus": { "type": "number", "description": "Young's modulus in Pa" },
                "density": { "type": "number", "description": "Density in kg/m^3" }
            }
        },
        "length": { "type": "number", "description": "Span in meters" }
    }
}
```

### Array of Objects

```json
{
    "type": "array",
    "maxItems": 10,
    "items": {
        "type": "object",
        "properties": {
            "x": { "type": "number" },
            "y": { "type": "number" }
        }
    }
}
```

Always include `description` fields. They are the primary way an LLM understands what each field represents.

## Effect on Tool Behavior

The schema influences whether a parameter passes by value (embedded in the tool call) or by reference (via a URL to external data).

When `build` generates a wrapper, it decides based on parameter size:
- If the argument block or the schema implies a bounded, small structure (`maxLiteralSize` elements or fewer, 64 by default): **literal** (by value)
- If both imply an unbounded or large structure: **externalized** (by reference via URL)

With `example`, `build` generates no wrapper, so every parameter passes by value and `x-call-by` has no effect.

To override this decision, use the `x-call-by` property:

```json
{
    "type": "array",
    "x-call-by": "value",
    "items": { "type": "object", "properties": { ... } }
}
```

Valid values: `"value"` (always literal) or `"reference"` (always externalized).

See [Wrapper Functions](../concepts/wrapper-functions.md) for full details on the externalization mechanism.

## Generated Schema Layout

When a wrapper externalizes a parameter, the tool's `inputSchema` describes the URL, and the schema of the data at the URL moves to `inputSchema.$defs`:

| Parameter | Property in `inputSchema.properties` | Schema of the data |
| :--- | :--- | :--- |
| Input `p` | `pURL`: a required string | `inputSchema.$defs.inputSchema.pURL` |
| Output `o` | `oURL`: an optional string with `writeOnly: true`, the location the tool writes `o` to | `inputSchema.$defs.outputSchema.oURL` |

Each URL property has an `examples` list of sample URLs (`file:///tmp/storage/data.csv` and others) and a description that starts with "URL pointing to the input value for" or "the output value for".

With Invertible [wire encoding](../concepts/wire-encoding.md), each URL description also names its `$defs` entry, as the text `"$ref": "#/$defs/inputSchema/pURL"`. It's a pointer for the model to follow, not a JSON Schema `$ref` keyword. The `$defs` entry then describes the encoded form: a bare value or a `{type, size, data}` object.

```json
"cleanURL": {
  "type": "string",
  "description": "URL pointing to the output value for 'clean'. ... Data at the URL formatted per \"$ref\": \"#/$defs/outputSchema/cleanURL\". ...",
  "examples": ["file:///tmp/storage/data.csv", "file:///c:/tmp/storage/data.csv", "http://server/writable/resource (PUT endpoint)"],
  "writeOnly": true
}
```

See [Schemas](../concepts/schemas.md) for a complete sample.

## File-Based Schemas

Schema files must be JSON and must exist when `prodserver.mcp.build` runs. A relative path resolves against the current folder or the MATLAB path, not the folder that holds the function file. Leading and trailing whitespace around the filename is ignored.

```MATLAB
%#schema =beam_spec.json       ← recommended style
%#schema = beam_spec.json      ← also valid (space after = is trimmed)
```

## Example

See the [Structured Data](../../Examples/StructuredData/StructuredData.md) example for a complete demonstration. It includes a beam analysis tool with two-level nested struct inputs alongside the circle intersection tool.

--- Copyright 2026 The MathWorks, Inc. ---
