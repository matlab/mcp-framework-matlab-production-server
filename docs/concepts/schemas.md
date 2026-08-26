# Schemas

A schema is a formal description of the structure, types, and constraints of data exchanged between systems. MCP Framework uses [JSON Schema](https://json-schema.org/understanding-json-schema/) to describe tool parameters — what the LLM must send and what it receives back.

## Why MCP Requires Schemas

The Model Context Protocol communicates via JSON-RPC. When an LLM calls a tool, it constructs a JSON request containing the tool's input arguments. Without a schema, the LLM cannot know:

- What parameters the tool accepts and what each one means
- What type each parameter requires (number, string, object, array)
- Which parameters are required and which are optional
- What constraints apply (ranges, allowed values, array sizes)

The schema is the contract between the LLM and the tool.

## JSON Schema and MATLAB Functions

MATLAB functions don't declare parameter types in the way that statically-typed languages do. The type of a MATLAB argument is only guaranteed at runtime, when the function is actually called. But MCP requires complete schemas at build time, before any calls happen.

JSON Schema treats variable type very differently than MATLAB. JSON Schema essentially supports 4 base types, numeric, boolean, string and object and arrays of each of them. Numbers may be integer or double, but JSON Schema has no notion of precision or bit-width. Those kinds of constraints may be imposed via a set of validation keywords -- setting a range via `minimum` and `maximum` for example. 

Rather than asking you to write JSON Schema by hand, the framework generates it automatically from the information you provide: comments, argument blocks, and example calls. See [Describing Functions](./describing-functions.md) for how to provide this information.

## From MATLAB Types to JSON Schema

The framework maps MATLAB classes to JSON Schema base types:

| MATLAB | JSON Schema | Notes |
| :--- | :--- | :--- |
| `double`, `single` | `"number"` | Floating-point types |
| `int*`, `uint*` | `"integer"` | All integer bit-widths |
| `char`, `string` | `"string"` | |
| `logical` | `"boolean"` | |
| `struct` | `"object"` with `"properties"` | Field schemas inferred from examples or `%#schema` |
| `cell` | `"array"` | |
| Non-scalar of any type | `{"type": "array", "items": {"type": "<base>"}}` | Fixed-size declarations add `"maxItems"` |

Scalars (size `(1,1)`) use the base type directly. Non-scalars are wrapped in an `"array"` with an `"items"` schema containing the base type. When the argument block declares a fixed size (e.g., `(1,3)` or `(2,4,3)`), the framework computes the total element count and adds `"maxItems"` to the array schema.

JSON Schema validation keywords like `minimum`, `maximum`, and `enum` are available via the `%#schema` pragma. Argument block constraints (e.g., `mustBePositive`) are captured as metadata but do not currently generate these keywords automatically.

## A Complete Generated Schema

Given this function:

```MATLAB
function sigma = principalStress(stressState, component)
% Compute principal stresses using Mohr's circle.
%
%    sigma = principalStress(stressState, component) computes the principal
%        stress component ("min", "max", "maxShear") in MPa from the 2D
%        stressState [tension, compression, shear].
    arguments
        stressState (1,3) double % 2D stress state [tension, compression, shear] in MPa
        component (1,1) string   % Principal stress component: "min", "max", or "maxShear"
    end
    ...
end
```

The framework produces this JSON Schema tool definition:

```json
{
  "name": "principalStress",
  "description": "Compute principal stresses using Mohr's circle.\n\n   sigma = principalStress(stressState, component) computes the principal\n       stress component (\"min\", \"max\", \"maxShear\") in MPa from the 2D\n       stressState [tension, compression, shear].",
  "inputSchema": {
    "type": "object",
    "properties": {
      "stressState": {
        "type": "array",
        "items": {"type": "number"},
        "description": "2D stress state [tension, compression, shear] in MPa"
      },
      "component": {
        "type": "string",
        "description": "Principal stress component: \"min\", \"max\", or \"maxShear\""
      }
    },
    "required": ["stressState", "component"]
  }
}
```

This is what the LLM receives when it queries the tool's capabilities. The function comment becomes the tool description. Argument block types and comments become property definitions.

## Combining Mechanisms

When multiple sources (comments, argument blocks, example calls) provide overlapping information, the framework merges them:

- **Comments** from argument blocks are always included, regardless of whether examples are also present
- **Observed types** from example calls fill gaps that argument blocks leave — struct field names, cell array contents, table variable names
- **Argument block constraints** take precedence for size declarations — a declared `(:,1)` is more general than observing a specific 5-element vector
- **The function comment block** is always required and always used as the tool description

When sources conflict on size, the argument block wins. When sources conflict on type (e.g., argument block says `double` but example shows `uint16`), the framework records both patterns.

## Large Data and Schema Interaction

When parameters are large (exceeding 64 elements), the framework generates a [wrapper function](./wrapper-functions.md) that replaces the array parameter with a URL string. The schema then describes the URL parameter:

```json
{
  "noisyURL": {
    "type": "string",
    "description": "file: URL pointing to input signal (double array)"
  }
}
```

The LLM never sees the schema for the underlying data structure. It provides a URL, and the wrapper handles deserialization.

## See Also

- [Describing Functions](./describing-functions.md) — how to provide type information via comments, examples, and argument blocks
- [Wrapper Functions](./wrapper-functions.md) — how large data changes the schema
- [Wire Encoding](./wire-encoding.md) — how MATLAB values are serialized as JSON
- [Schema Format reference](../reference/schema-format.md) — `%#schema` pragma syntax
- [`build` reference](../reference/build.md) — full `build` API

--- Copyright 2026 The MathWorks, Inc. ---
