# What is a Schema?

A schema is a formal description of the structure, types, and constraints of data exchanged between systems. Schemas appear throughout computing: database schemas define column types and constraints, API specifications (OpenAPI/Swagger) describe request and response formats, and message serialization systems (Protocol Buffers, Avro) define wire formats.

MCP Framework uses [JSON Schema](https://json-schema.org/understanding-json-schema/) — a standard vocabulary for describing JSON data structures. JSON Schema is widely supported by LLMs and developer tools, making it the natural choice for describing MCP tool parameters.

# Why MCP Requires Schemas

The Model Context Protocol defines a tool API that communicates via JSON-RPC. When an LLM calls a tool, it must construct a valid JSON request containing the tool's input arguments. Without a schema, the LLM cannot know:

* What parameters the tool accepts and what each one means
* What type each parameter requires (number, string, object, array)
* Which parameters are required and which are optional
* What constraints apply to parameter values (ranges, allowed values, sizes)

The schema is the contract between the LLM and the tool. It tells the LLM exactly how to format data for each parameter. Schemas convey aspects of types that are not obvious from the value alone — units, valid ranges, encoding rules, and operational behaviors. For example, a tool that accepts a frequency parameter needs the LLM to know not just that the value is a number, but that it represents Hertz and must be positive.

Large data (signals, images, tables) typically persists in external storage and is passed by reference — the schema describes the format of the reference (a URL string) rather than the data itself. See [Externalize Data Sources and Sinks](./ExternalData.md) for details on external data handling.

# Schemas for MATLAB Functions
Schemas are type declarations, and MATLAB functions don't declare the types of their parameters. The type of a MATLAB argument is only guaranteed to be known at runtime, when the function is actually called. In order to describe a tool to an LLM the MCP Framework requires complete schemas at tool build time, before any calls happen. 

JSON Schema is meant for machines, not people. Rather than asking you to write an entire schema, the MCP Framework can examine your MATLAB functions and automatically generate a schema. But the MCP Framework needs some help from you. MCP Framework supports three complementary mechanisms for providing argument data types. All three may be used together or separately:

1. **MATLAB argument blocks** — work well for primitive types but only partially for containers
2. **Tests that exercise the tool function** — full runtime type knowledge via observation
3. **`%#schema` pragma** — explicit annotation for complex structured types

## Argument Blocks

When your function declares `arguments(Input)` and `arguments(Output)` blocks, MCP Framework reads the size, type, description, and default value of each parameter to generate schema fragments automatically.

For scalar primitives — `double`, `string`, `logical`, and integer types — argument blocks alone produce complete and correct schemas:

```MATLAB
function seq = primeSequence(n, type)
% Return the first N primes of the given sequence type.
    arguments(Input)
        n (1,1) double    % Length of the generated sequence
        type (1,1) string % Name of the sequence to generate
    end
    arguments(Output)
        seq double  % Generated sequence of prime numbers
    end
```

From this, MCP Framework generates:
* `n` → `{"type": "number", "description": "Length of the generated sequence"}`
* `type` → `{"type": "string", "description": "Name of the sequence to generate"}`
* `seq` → `{"type": "array", "items": {"type": "number"}, "description": "Generated sequence of prime numbers"}`

Argument blocks cannot describe the internal structure of containers. A `struct` declaration tells the framework only that the parameter is an object — not what fields it contains, what types those fields have, or how deeply nested the structure is. For container types, use tests or the `%#schema` pragma.

See [Describing MATLAB Functions](./DescribingFunctions.md) for full detail on how comments and argument blocks contribute to tool definitions.

## Tests

When argument blocks are insufficient — or absent entirely — you can generate schemas by exercising your functions with representative inputs. MCP Framework observes actual argument values at runtime and infers JSON Schema types from them.

**How it works:**

1. `prodserver.mcp.schema` creates shadow wrappers that intercept calls to your functions
2. Runs your tests, which call the functions through the shadow wrappers
3. Records each argument's type and structure as a JSON Schema fragment
4. Merges all fragments into complete tool definitions

**Standalone usage:**
```MATLAB
defs = prodserver.mcp.schema("myFunction", @() myFunction(1.0, "hello"));
prodserver.mcp.build("myFunction", definition=defs);
```

**Integrated with build:**
```MATLAB
ctf = prodserver.mcp.build("myFunction", tests=@() myFunction(1.0, "hello"));
```

The `tests` argument accepts several forms:
* Function handles: `@() myFunction(1, 2, 3)`
* Test file paths (.m): `"test/myToolTests.m"`
* Folder paths: `"test/myToolTests"`
* Function or script names: `"exerciseMyTool"`
* Cell arrays combining any of the above: `{@handle1, "test/extra.m"}`

**Advantages:**
* Full knowledge of runtime types including containers, nested structs, datetime, duration, and tables
* Works for functions that lack argument blocks entirely
* Captures exact field names and nesting of structured parameters
* Multiple test calls reveal which parameters are optional (those not present in every call)

**Limitations:**
* The test suite may not capture all possible types if not all code paths are exercised
* All functions passed to `schema()` must be called at least once during test execution
* Name-value pair arguments appear in the schema only if the tests actually use them
* For functions without argument blocks, requiredness is inferred from the minimum observed argument count — if tests always pass all arguments, all will appear required

**Combining tests with argument blocks:** For best results, provide both. Argument blocks supply parameter names, descriptions, and basic type constraints. Tests fill in the details that argument blocks cannot express — container field names, nested structures, and runtime-only types.

**Inferring optional parameters:** Call the function with different numbers of arguments to communicate which are optional:
```MATLAB
defs = prodserver.mcp.schema("flexFunction", ...
    {@() flexFunction(1, 2), ...
     @() flexFunction(1, 2, 3, 4, 5)});
```
Here the framework observes that the minimum call uses 2 arguments, so parameters 3-5 are optional.

See [`prodserver.mcp.schema`](./schema.md) for the complete API reference.

## %#schema

For struct parameters where you need complete control over the schema, annotate them with the `%#schema` pragma in comments above the parameter declaration:

```MATLAB
arguments (Input)
    % Beam specification with material and geometry.
    %#schema =beam_spec.json
    beam_spec (1,1) struct
end
```

Three modes are supported:
* **Replace** (`=`) — completely replaces the auto-generated schema with yours
* **Additive** (`+`) — merges your schema with the auto-generated one
* **Inline JSON** — provides the schema directly in the comment text

For full details on pragma syntax, JSON Schema patterns, file resolution, and behavioral effects, see [Schema Format Reference](./SchemaFormat.md).

For a complete working example combining `%#schema` with argument blocks, see the [Structured Data](../Examples/StructuredData/StructuredData.md) example.

For the JSON Schema specification itself, see [json-schema.org](https://json-schema.org/understanding-json-schema/).

--- Copyright 2026 The MathWorks, Inc. ---
