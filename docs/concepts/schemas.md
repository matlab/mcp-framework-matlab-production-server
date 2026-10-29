# Schemas

A schema is a formal description of the structure, types, and constraints of data exchanged between systems. MCP Framework uses [JSON Schema](https://json-schema.org/understanding-json-schema/) to describe tool parameters — what the LLM must send and what it receives back.

## Why MCP Requires Schemas

The Model Context Protocol communicates via JSON-RPC. When an LLM calls a tool, it constructs a JSON request containing the tool input arguments. Without a schema, the LLM cannot know:

- What parameters the tool accepts and what each one means
- What type each parameter requires (number, string, object, array)
- Which parameters are required and which are optional
- What constraints apply (ranges, allowed values, array sizes)

The schema is the contract between the LLM and the tool.

## JSON Schema and MATLAB Functions

MATLAB functions do not declare parameter types in the way that statically-typed languages do. The type of a MATLAB argument is only guaranteed at runtime, when the function is actually called. But MCP requires complete schemas at build time, before any calls happen.

JSON Schema treats variable type very differently than MATLAB. JSON Schema essentially supports four base types: numeric, boolean, string, and object, and arrays of each of them. Numbers may be integer or double, but JSON Schema has no notion of precision or bit-width. Those kinds of constraints may be imposed via a set of validation keywords—setting a range via `minimum` and `maximum` for example.

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
| Non-scalar of any type | `{"type": "array", "items": {"type": "<base>"}}` | Fixed-size declarations add `"minItems"` and `"maxItems"` |

Scalars (size `(1,1)`) use the base type directly. Non-scalars are wrapped in an `"array"` with an `"items"` schema containing the base type. The declared size decides this, not the example calls: a `(:,1)` argument is an array even if every example passes a scalar. When the argument block declares a fixed size (e.g., `(1,3)` or `(2,4,3)`), the framework computes the total element count and adds it to the array schema as both `"minItems"` and `"maxItems"`, because MATLAB requires exactly that many elements.

### Dates and Durations

Plain JSON has no date or duration type, so under `encoding="JSON"` the framework converts them, in both directions:

| MATLAB | JSON value | JSON Schema |
| :--- | :--- | :--- |
| `datetime` | ISO 8601 text: `"2026-01-02T03:04:05.000"`, with a `Z` suffix in UTC or an offset such as `-05:00` in another time zone. The seconds have more decimal places, up to nine, when the value needs them. NaT is `null`. | `{"type": ["string", "null"], "format": "date-time"}` |
| `duration` | Its length in seconds. A duration of NaN seconds is `null`. | `{"type": ["number", "null"], "x-matlab-class": "duration"}` |

An array of either is an array of these values. The conversion follows the schema, so it applies at any depth: to an argument, an element of an array argument, or a field of a struct argument. `prodserver.mcp.call` follows the output schema in the same way, so it returns a datetime or duration output as a `datetime` or `duration`.

An input must be strict ISO 8601: a date (`2026-01-02`), or a date and time (`2026-01-02T03:04`, `2026-01-02T03:04:05` or `2026-01-02T03:04:05.250`, with any number of decimal places), optionally followed by `Z` or an offset. The time zone is unzoned with no suffix, UTC with `Z`, or a fixed offset. Anything else is rejected as an invalid argument, including forms whose meaning depends on the locale, such as `01/02/2026`, and dates that don't exist, such as `2026-02-30`. So is an array whose elements don't share one time zone: some with a zone and some without, or different offsets. `Z` and `+00:00` are the same offset.

A datetime in a named time zone, such as `America/New_York`, goes out with its offset, and comes back as a datetime fixed at that offset: the same instant, without the zone's daylight-saving rules. An array in any zone other than UTC goes out in UTC, because an array that crosses a daylight-saving change has more than one offset, and comes back in UTC. The [invertible wire encoding](./wire-encoding.md) keeps the zone name.

### Classes Plain JSON Can't Carry

Plain JSON has no representation for `categorical`, `table` or `timetable`. Only the [invertible wire encoding](./wire-encoding.md) carries them, so `build` stops with an `IncompatibleArgumentType` error if a parameter has one of these classes and the tool uses `encoding="JSON"`. With `encoding="Invertible"`, the parameter's schema describes the encoded value itself: for example, a table is an object with `"type": {"enum": ["table"]}` and a `"variables"` array, and a scalar datetime is an ISO 8601 string, `"NaT"`, or, in a named time zone, the datetime wrapper with a `"tz"` field.

No wire encoding carries function handles, `containers.Map`, `calendarDuration` or other classes, so `build` always stops with the same error for them. That includes a value of such a class inside a struct field or a cell. To pass one anyway, convert it in a [wrapper function](./wrapper-functions.md), or map its class to a JSON type with the `typemap` option and convert the value yourself.

JSON Schema validation keywords like `minimum`, `maximum`, and `enum` are available via the `%#schema` pragma. Argument block constraints (e.g., `mustBePositive`) are captured as metadata but do not currently generate these keywords automatically. Under `encoding="Invertible"`, though, class-restricting validators such as `mustBeNumeric`, `mustBeFloat` and `mustBeText` limit the classes the wrapper's `"type"` may name, for a parameter with no declared class: see [Wire Encoding](./wire-encoding.md#the-encoding-format).

## A Complete Generated Schema

Given this function, from [`Examples/PrincipalStress`](../../Examples/PrincipalStress/walkthrough.md):

```MATLAB
function sigma = principalStress(stressState, component)
% Compute principal stresses using Mohr's circle.
%
%    sigma = principalStress(stressState, component) computes the principal
%        stress component ("min", "max", "maxShear") in MPa from the 2D
%        stressState [tension, compression, shear].
    arguments(Input)
        stressState (1,3) double  % 2D stress state [sigma_x, sigma_y, tau_xy] in MPa
        component (1,1) string    % Principal stress component: "max", "min", or "maxShear"
    end
    arguments(Output)
        sigma (1,1) double        % Computed principal stress in MPa
    end
    ...
end
```

The framework produces this JSON Schema tool definition. Because `stressState` is declared `(1,3)`, its schema has `"minItems": 3` and `"maxItems": 3`:

```json
{
  "name": "principalStress",
  "description": "Compute principal stresses using Mohr's circle.  sigma = principalStress(stressState, component) computes the principal stress component (\"min\", \"max\", \"maxShear\") in MPa from the 2D stressState [tension, compression, shear].",
  "inputSchema": {
    "type": "object",
    "properties": {
      "stressState": {
        "type": "array",
        "items": {"type": "number"},
        "minItems": 3,
        "maxItems": 3,
        "description": "2D stress state [sigma_x, sigma_y, tau_xy] in MPa"
      },
      "component": {
        "type": "string",
        "description": "Principal stress component: \"max\", \"min\", or \"maxShear\""
      }
    },
    "required": ["stressState", "component"],
    "minProperties": 2,
    "maxProperties": 2
  },
  "outputSchema": {
    "type": "object",
    "properties": {
      "sigma": {
        "type": "number",
        "description": "Computed principal stress in MPa"
      }
    },
    "required": [],
    "minProperties": 0,
    "maxProperties": 1
  }
}
```

This is what the LLM receives when it queries the tool capabilities. The function comment becomes the tool description. Argument block types and comments become property definitions, the input block in `inputSchema` and the output block in `outputSchema`.

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
    "description": "URL pointing to the input value for 'noisy'. The content of the URL is:\nNoisy signal",
    "examples": [ "file:///tmp/storage/data.csv", "file:///c:/tmp/storage/data.csv", "..." ]
  }
}
```

The LLM provides a URL, and the wrapper handles deserialization. The schema of the underlying data isn't lost: the framework moves it to `$defs` in the tool's `inputSchema`, under `inputSchema` for inputs and `outputSchema` for outputs, keyed by the URL parameter's name. For a tool built with `encoding="Invertible"`, the parameter's description also points the LLM to that schema, for example `"$ref": "#/$defs/inputSchema/noisyURL"`, since the data at the URL must be wire-encoded.

## See Also

- [Describing Functions](./describing-functions.md) — how to provide type information via comments, examples, and argument blocks
- [Wrapper Functions](./wrapper-functions.md) — how large data changes the schema
- [Wire Encoding](./wire-encoding.md) — how MATLAB values are serialized as JSON
- [Schema Format reference](../reference/schema-format.md) — `%#schema` pragma syntax
- [`build` reference](../reference/build.md) — full `build` API

--- Copyright 2026 The MathWorks, Inc. ---
