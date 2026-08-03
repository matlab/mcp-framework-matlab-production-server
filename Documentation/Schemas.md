# Structured Data and Schemas

```MATLAB
arguments (Input)
    % Description of the parameter.
    %#schema =my_schema.json
    param (1,1) struct
end
```

The `%#schema` pragma annotates struct parameters with JSON Schema definitions so that LLMs know what fields to provide when calling your tool.

## The Problem

MATLAB's `arguments` blocks can declare that a parameter is a `struct`, but cannot specify what fields that struct must contain:

```MATLAB
arguments
    config (1,1) struct    % What fields? What types? What nesting?
end
```

An LLM reading this tool definition sees only `"type": "object"` with no further detail. It cannot construct a valid input without guessing — or asking the user.

## Why Schemas Matter for MCP

When MCP Framework generates a tool definition, it converts each parameter's type and constraints into a JSON Schema fragment. For scalars and arrays of primitive types, this works automatically. But for structures — especially nested ones — the auto-generated schema says nothing about field names, nesting or value types.

An LLM needs to know:
- What fields the struct contains
- What type each field has
- What each field means (via descriptions)
- How deeply nested the structure is

The `%#schema` pragma supplies this information.

## The `%#schema` Pragma

Place `%#schema` in the comment block above a parameter declaration. It must appear as the **last comment line** before the declaration. Three syntax forms are supported:

### Replace mode (`=`)

Completely replaces any auto-generated schema with the user-supplied schema.

```MATLAB
% Beam specification with material and geometry.
%#schema =beam_spec.json
beam_spec (1,1) struct
```

Use this when your schema fully describes the parameter and you do not want MCP Framework to add anything (such as `maxItems` or array wrappers).

### Additive mode (`+`)

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

## Schema Format

Schemas follow the JSON Schema vocabulary. The most common patterns for MATLAB struct parameters:

### Flat object (one level)

```json
{
    "type": "object",
    "properties": {
        "temperature": { "type": "number", "description": "Temperature in Celsius" },
        "pressure": { "type": "number", "description": "Pressure in Pascals" }
    }
}
```

### Nested object (two levels)

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

### Array of objects

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

## File-Based Schemas

Schema files must be JSON and must exist when `prodserver.mcp.build` runs. The file path is resolved relative to the function file's location. Leading and trailing whitespace around the filename is ignored:

```MATLAB
%#schema =beam_spec.json       ← recommended style
%#schema = beam_spec.json      ← also valid (space after = is trimmed)
```

## Example

See the [Structured Data](../Examples/StructuredData/StructuredData.md) example for a complete demonstration: a beam analysis tool with 2-level nested struct inputs alongside the circle intersection tool.

--- Copyright 2026 The MathWorks, Inc. ---
