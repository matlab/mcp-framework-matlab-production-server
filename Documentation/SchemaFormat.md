# Schema Format Reference

Detailed reference for the `%#schema` pragma and JSON Schema patterns used by MCP Framework. For conceptual background on why schemas are needed and how they are generated, see [Schemas](./Schemas.md).

## The `%#schema` Pragma

Place `%#schema` in the comment block above a parameter declaration. It must appear as the **last comment line** before the declaration. Three syntax forms are supported:

### Replace Mode (`=`)

Completely replaces any auto-generated schema with the user-supplied schema.

```MATLAB
% Beam specification with material and geometry.
%#schema =beam_spec.json
beam_spec (1,1) struct
```

Use this when your schema fully describes the parameter and you do not want MCP Framework to add anything (such as `maxItems` or array wrappers).

### Additive Mode (`+`)

Merges the user schema with the auto-generated schema. User-supplied properties overwrite auto-generated ones where they conflict.

```MATLAB
% A vector of circles with known maximum length.
%#schema +circle.json
circles (1,17) struct
```

Use this when you want MCP Framework to auto-generate container-level properties (like `maxItems` from the fixed dimension `17`) but supply the item-level schema yourself.

### Inline JSON

Provide a JSON Schema fragment directly in the comment:

```MATLAB
% Coordinates of the target.
%#schema { "type": "object", "properties": { "x": {"type": "number"}, "y": {"type": "number"} } }
target (1,1) struct
```

Use this for simple schemas where a separate file would be overhead. Without a prefix, inline JSON uses **additive** merge (same as `+`). To completely replace the auto-generated schema with inline JSON, use `=`:

```MATLAB
%#schema ={ "type": "object", "properties": { "x": {"type": "number"}, "y": {"type": "number"} } }
```

## JSON Schema Patterns

Schemas follow the [JSON Schema](https://json-schema.org/understanding-json-schema/) vocabulary. The most common patterns for MATLAB struct parameters:

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

Always include `description` fields — they are the primary way an LLM understands what each field represents.

## Effect on Tool Behavior

The schema influences whether a parameter is passed by value (embedded in the tool call) or by reference (via a URL to external data).

MCP Framework decides based on parameter size:
- If the schema implies a bounded, small structure (≤ 64 items): **literal** (by value)
- If the schema implies an unbounded or large structure: **externalized** (by reference via URL)

You can override this decision with the `x-call-by` property:

```json
{
    "type": "array",
    "x-call-by": "value",
    "items": { "type": "object", "properties": { ... } }
}
```

Valid values: `"value"` (always literal) or `"reference"` (always externalized).

See [Externalize Data Sources and Sinks](./ExternalData.md) for full details on the externalization mechanism.

## File-Based Schemas

Schema files must be JSON and must exist when `prodserver.mcp.build` runs. The file path is resolved relative to the function file's location. Leading and trailing whitespace around the filename is ignored:

```MATLAB
%#schema =beam_spec.json       ← recommended style
%#schema = beam_spec.json      ← also valid (space after = is trimmed)
```

## Example

See the [Structured Data](../Examples/StructuredData/StructuredData.md) example for a complete demonstration: a beam analysis tool with 2-level nested struct inputs alongside the circle intersection tool.

--- Copyright 2026 The MathWorks, Inc. ---
