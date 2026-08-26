# Describing Functions

The framework generates a tool description for every function you deploy. This description is what the LLM reads when deciding whether and how to call your tool. A good description is complete (covers all parameters, their types, and valid values) and precise (leaves no room for misinterpretation).

You provide the raw material. The framework assembles it into a JSON Schema tool definition that MCP clients understand. To see what the generated schema looks like and how the framework maps MATLAB types to JSON Schema, see [Schemas](./schemas.md).

## Three Sources of Information

The framework draws from three sources, each contributing different aspects of the description:

| Source | What it provides |
| :--- | :--- |
| Function comments | Purpose, semantics, valid values, units |
| Example calls | Observed types and shapes of inputs and outputs at runtime |
| Argument blocks | Declared constraints, sizes, and per-parameter documentation |

All three can work together. Comments provide meaning. Examples provide runtime type evidence. Argument blocks provide formal constraints and per-argument documentation. For simple data types like numeric arrays, two sources may be sufficent: the function comment and either argument blocks or example calls. 

## Function Comments

The comment block immediately after the `function` line describes the tool's **purpose**. The LLM reads this text to understand what the tool does and when to use it.

```MATLAB
function sigma = principalStress(stressState, component)
% Compute principal stresses using Mohr's circle.
%
%    sigma = principalStress(stressState, component) computes the principal
%        stress component ("min", "max", "maxShear") in MPa from the 2D
%        stressState [tension, compression, shear].
%
%  Example:
%    sigma = principalStress([120 -50 80], "max") returns 151.73 MPa.
```

The first contiguous block of comment lines is captured. A blank line or non-comment line terminates the block. Copyright notices and internal implementation comments that appear after a blank line are excluded.

### Writing effective comments

Write for the LLM, not for MATLAB's help system:

- State what each parameter means, not just its name
- List valid values or ranges ("min", "max", "maxShear")
- Include units (MPa, Hz, meters)
- Add an example call with expected output — LLMs use examples to validate their understanding of the interface

LLMs perform measurably better when tool descriptions contain concrete usage examples. Follow the MathWorks documentation pattern: show a representative call and state the expected result. This gives the LLM a template it can adapt to the user's prompt.

## Example Calls

The `example` argument to `build` tells the framework how your function is called. The framework runs each example and observes the types and shapes of both inputs and outputs. Example calls provide the framework with detail on the internal structure of your data, such as:

- Struct field names and nesting
- Cell array contents
- Table variable names and column types

```MATLAB
% Your function
function sigma = principalStress(stressState, component)

% Build using example call
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));
```

From this single call, the framework records:
- `stressState`: 3-element double row vector
- `component`: string scalar
- `sigma` (output): double scalar

### Multiple examples for type variation

When a parameter accepts different types across calls, provide multiple examples:

```MATLAB
% Function with varying input types
function celsius = convertSensor(reading, channel)

% Build using multiple examples
ctf = prodserver.mcp.build("convertSensor", ...
    example={@() convertSensor(uint16(rawCounts), "temperature"), ...
             @() convertSensor(voltages, "temperature")});
```

The framework sees that `reading` is sometimes `uint16` and sometimes `double`, and records both patterns. 

Specify multiple examples via a vector of:
- Function handles
- Function or script names
- Full or relative paths to function or script files
- Folders containing MATLAB unit test classes
Function handles are the most immediate and folders of test classes the most complete.

### Inferring optional parameters

Call the function with different numbers of arguments to communicate which are optional:

```MATLAB
% Function with optional positional inputs
function smooth = smoothSignal(signal, windowSize, overlap)

% Build with multiple examples
ctf = prodserver.mcp.build("smoothSignal", ...
    example={@() smoothSignal(signal, 5), ...
             @() smoothSignal(signal, 5, 3)});
```

The framework observes that the minimum call uses 2 arguments (`signal` and `windowSize`), so `overlap` is marked optional in the schema.

## Argument Blocks

When your function declares `arguments` blocks, the framework reads type, size, comments and constraints from them. 
Constraints describe characteristics of an argument that limit the values a variable can take within its type -- `mustBePositive` or `mustBeSorted` for example. 

Argument blocks may provide complete or partial type information. When only partial information can be specified explicit JSON schemas provide the rest.

### Usage Patterns

Each declaration in an argument block contains a name and one or more of these properties: type, size, comment, constraint and default value. This declaration specifies a row vector of doubles which must be positive and sorted, with a default value of [17, 64, 81].

```MATLAB
% Fluid density in grams per milliliter
density (1,:) double { mustBePositive, mustBeSorted } = [17, 64, 81]
```
All of the properties are optional. The MCP Framework will capture whatever information the declaration provides.

You use argument blocks in one of three ways:
- Completely specify simple types
- Augment the type observed in example calls 
- Specify argument properties with JSON Schema declarations

**1. Simple data — complete declaration**
If the arguments are simple types with consistent sizes, argument blocks can describe them completely.

```MATLAB
function count = countExceedances(measurements, threshold)
    arguments
        measurements (:,1) double  % Time series of sensor readings
        threshold (1,1) double     % Level above which a reading counts
    end
    arguments (Output)
        count (1,1) uint32         % Number of readings exceeding the threshold
    end
    count = uint32(sum(measurements > threshold));
end
```

The framework generates a complete schema from declarations alone. No `example` needed.

**2. Structured or variable type data - augment example-inferred type**
For arguments with internal structure argument blocks fill in gaps left by the example calls. 

This `struct` declaration and comment tells the framework that the `material` parameter is a column vector of material properties.

```MATLAB
function result = analyzeMaterial(material, load)
    arguments
        material (:,1) struct  % Material properties
        load (1,1) double % Applied load in Newtons
    end
    ...
end
```
The example call provides the framework with the field names and their types:

```MATLAB
ctf = prodserver.mcp.build("analyzeMaterial", ...
    example=@() analyzeMaterial(struct('name','steel','E',200e9,'nu',0.3), 1000));
```
The same pattern applies to functions that accept varying types. The declaration of `reading` specifies both shape and purpose:

```MATLAB
function celsius = convertSensor(reading, channel)
    arguments
        reading (:,1)  % Raw ADC counts (uint16) or calibrated voltages (double)
        channel        % Sensor channel name
    end
    ...
end
```
The framework extracts the shapes and comments and relies on `example` calls for type information. 

**3. Structured data with `%#schema` — explicit annotation**

When examples alone are insufficient (in case of optional fields, constrained values, deeply nested structures), annotate the argument with the `%#schema` pragma:

```MATLAB
    arguments (Input)
        % Beam specification with material and geometry.
        %#schema =beam_spec.json
        beam_spec (1,1) struct
    end
```

`%#schema` allows you to affect the generated description in two ways: replace it (`=`) or add to it (`+`). You provide type information via either a JSON file or inline. See the [Schema Format reference](../reference/schema-format.md) for full syntax.

### Comment placement

Two styles are supported and can be mixed:

- **Right-side comments** — concise, on the same line as the argument:
  ```MATLAB
  threshold (1,1) double % Level above which a reading counts
  ```

- **Above comments** — for longer descriptions, on the line(s) before the argument:
  ```MATLAB
  % A five-dimensional array specifying pixel colors.
  % Width x Height x [R,G,B].
  img double
  ```

The comment and argument must be contiguous — no blank line between them.

### Output argument blocks

Output arguments follow the same rules. Declaring output types helps the LLM interpret results:

```MATLAB
    arguments (Output)
        % Generated sequence of prime numbers
        seq double
    end
```

## How the Sources Combine

When multiple sources provide overlapping information, the framework merges them into a single schema. See [Schemas — Combining Mechanisms](./schemas.md#combining-mechanisms) for the merge rules and precedence.

## Choosing an Approach

| Situation | Approach |
| :--- | :--- |
| Simple types, argument blocks declared | Argument blocks alone may suffice |
| Complex types (structs, cells, tables) | Use `example` — always |
| No argument blocks | Use `example` |
| Different types at the same position | Multiple examples |
| Want output types documented | Use `example` or output argument blocks |
| Argument blocks + want richer type detail | Combine both |

## See Also

- [Building MCP Tools](../guides/building-tools.md) — the build-deploy workflow
- [Schemas](./schemas.md) — what a JSON Schema tool definition is
- [Schema Format reference](../reference/schema-format.md) — `%#schema` pragma syntax
- [`build` reference](../reference/build.md) — full API details

--- Copyright 2026 The MathWorks, Inc. ---
