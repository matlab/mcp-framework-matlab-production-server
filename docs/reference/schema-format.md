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

```MATLAB
% One number, or a list of numbers.
%#schema ={"anyOf": [{"type": "number"}, {"type": "array", "items": {"type": "number"}}]}
x (1,:) double
```

A replacing schema may be a union, `anyOf` or `oneOf` with no `type`, or list several types, such as `"type": ["number", "null"]`, for the value or for an array's `items`. `build` publishes it as given. When the schema states a single `type`, `build` checks it against the class the `arguments` block declares; a union or a list has nothing to check. A value of the wrong class then reaches the function, and MATLAB's argument validation rejects it.

Under `encoding="Invertible"`, a parameter declared in an `arguments` block needs a single `type`, and so do its `items`, because the schema describes the elements of the wrapper's `data`. Without one, `build` stops with an `InvalidParameterSchema` error.

### Additive Mode (`+`)

Merges the user schema with the auto-generated schema. User-supplied properties overwrite auto-generated ones where they conflict.

```MATLAB
% A vector of circles with known maximum length.
%#schema +circle.json
circles (1,17) struct
```

Use additive mode when you want MCP Framework to auto-generate container-level properties (like `minItems` and `maxItems` from the fixed dimension `17`) but supply the item-level schema yourself.

Under `encoding="JSON"`, an added union, `anyOf` or `oneOf` with no `type`, replaces the generated `type`. Otherwise `"type": "array"` would still refuse the number that a union of a number and an array allows. The generated `items`, `minItems` and `maxItems` stay, as they constrain only arrays.

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

### Allowed Values

```MATLAB
% Gear: 1, 2 or 3.
%#schema {"enum": [1, 2, 3]}
gear (1,1) double
```

An `enum` lists the values a parameter accepts. Its members can be numbers, strings, booleans, arrays or objects. The server rejects a call with any other value before your function runs. `build` publishes `enum` and `examples` as JSON arrays, as you wrote them, even with one member.

MATLAB doesn't distinguish a one-element array from its element, and neither does the published schema. `"default": [5]` is published as `"default": 5`, and the member `[5]` in an `examples` list as `5`. Your function receives the same value either way.

### Checked Constraints

```MATLAB
% Batch code: three capitals, a hyphen and two digits.
%#schema {"pattern": "^[A-Z]{3}-\\d{2}$", "maxLength": 6}
code (1,1) string
```

The server checks these keywords before your function runs, and rejects a call that breaks one with a message naming the argument, such as `Argument 'code': string "abc-12" does not match the pattern "^[A-Z]{3}-\\d{2}$".`

| Applies to | Keywords |
| :--- | :--- |
| any value | `type`, `enum`, `const`, `anyOf`, `oneOf`, `allOf` |
| numbers | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf` |
| strings | `minLength`, `maxLength`, `pattern`, `"format": "date-time"` |
| arrays | `items`, `minItems`, `maxItems`, `uniqueItems` |
| objects | `properties`, `required`, `minProperties`, `maxProperties`, `"additionalProperties": false` |

Keywords beside `anyOf`, `oneOf` or `allOf` apply too, so `{"anyOf": [{"type": "number"}], "minimum": 5}` rejects 1. In a schema with no `type`, the array keywords don't apply to a single value, as in JSON Schema. That's how the generated `minItems` beside an added union constrains only the array branch. Nor do they apply to `null` when an alternative allows it, so `{"anyOf": [{"type": "array"}, {"type": "null"}], "minItems": 3}` accepts `null`.

In a list of types, a single value is checked as one value before it's checked as an array, whatever the order of the list. So `{"type": ["array", "string"], "maxLength": 3}` rejects `"abcdef"`, and `{"type": ["array", "number"], "minItems": 2}` accepts `5`.

The server checks `"format": "date-time"` only where the schema's `type` is `"string"`, or a list that includes it. With no `type`, or beside an `anyOf`, any text passes.

`enum`, `const` and `uniqueItems` compare values as JSON does. A number never equals a boolean or a string, so `{"enum": ["A"]}` rejects `65`, and `null` equals `null`.

The value of a keyword must be one the server can check. `build` stops with an `InvalidParameterSchema` error for a length or count that isn't a non-negative integer, such as `"maxLength": null`, for a bound that isn't a number, for a `multipleOf` that isn't greater than 0, or for a `uniqueItems` that isn't `true` or `false`. A boolean `exclusiveMinimum` or `exclusiveMaximum`, as in draft-04, is accepted: `true` makes `minimum` or `maximum` exclusive.

MATLAB treats a scalar as an array of one element, and so does the server: `7` satisfies `{"type": "array", "items": {"type": "number"}}`. In a `oneOf`, though, the server first counts the branches a value matches as JSON Schema does, so `7` matches `{"type": "number"}` but not an array branch, and `oneOf` accepts it. Only if no branch matches does it read the value as an array of one.

The server sees the arguments after JSON decoding, which gives `[7]` and `7` as the same MATLAB value. So it can't apply a rule that tells them apart: it accepts `[7]` for `{"oneOf": [{"type": "number"}, {"type": "array", "minItems": 2}]}`, which JSON Schema rejects. Your function receives `7`.

`build` publishes other keywords, such as `not` or `patternProperties`, for the client to read, but the server doesn't check them. Your `arguments` block is always enforced, by MATLAB, when the function runs.

A string's length counts characters as JSON Schema does, so an emoji is one character, not the two UTF-16 code units MATLAB counts.

JSON Schema's patterns are ECMAScript regular expressions. The server translates a `pattern` into MATLAB's syntax and matches it with `regexp`, so it matches what ECMAScript matches:

- `\d`, `\w` and `\b` use ASCII digits and word characters, as in ECMAScript. MATLAB's `\d` and `\w` also match other scripts' digits and letters.
- `\s` is ECMAScript's whitespace, and `.` matches any character except a line terminator.
- `\<` and `\>` are the characters `<` and `>`. In MATLAB they are word boundaries.
- `\xHH`, `\uHHHH` and `\cX` are the characters they name.
- A `[` inside brackets is the character, as in `[^[]`. In MATLAB it starts brackets inside them.
- A `{` that doesn't start a quantifier such as `{2}` or `{1,3}` is the character, as in `a{` or `x{,3}`.

`build` stops with an `InvalidParameterSchema` error for a pattern the server can't translate:

- MATLAB dynamic expressions, `(?@cmd)` and `(??expr)`.
- Inline flags, such as `(?i)`. ECMAScript has none, so a client that compiles the pattern would reject the tool's schema. List both cases instead, as in `[Aa]`.
- Possessive quantifiers, such as `a++` or `a{2}+`, for the same reason. Leave out the second `+`, or write `\+` for the character.
- Malformed syntax, such as an unmatched `[` or `(`.
- `\p{...}` Unicode classes, `\D`, `\W`, `\S` or `\B` inside brackets, and letter escapes that ECMAScript doesn't define, such as `\a`.
- A POSIX class such as `[:alpha:]` inside brackets, as in `[[:alpha:]]`. ECMAScript has none, and reads it as the characters `[`, `:`, `a` and so on. Write `\[` if you mean the characters.
- A range out of order, such as `[z-a]`, which ECMAScript rejects too.
- A backreference to a group the pattern doesn't have, such as `\8` in a pattern with fewer than eight groups. ECMAScript reads it as a character, and MATLAB as a backreference.
- A backreference above `\9`, which MATLAB can't match. Name the group and use `\k<name>` instead.
- `\1` to `\9` inside brackets, which are octal escapes in ECMAScript.
- An octal escape outside brackets, such as `\01`. `\0` with no digit after it is the null character.

Use a character range instead of `\p{...}`, such as `[A-Za-z]` for `\p{L}`.

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
