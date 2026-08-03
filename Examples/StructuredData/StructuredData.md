# Structured Data with Schemas

This example demonstrates how to use the `%#schema` pragma to describe struct parameters so that LLMs can construct valid tool inputs. Two MCP tools with structured inputs are built into separate servers.

## The Problem

MATLAB's `arguments` blocks can declare that a parameter is a `struct`, but cannot describe its fields. Without additional information, the auto-generated MCP tool definition says only `"type": "object"` — giving an LLM no way to know what fields to provide.

The `%#schema` pragma solves this by embedding a JSON Schema definition in the tool's metadata. See [Documentation/Schemas.md](../../Documentation/Schemas.md) for full reference.

## Tools

### circlesIntersect

Tests whether any circles in two lists overlap. Demonstrates a schema with one level of nesting (array of objects, each with a nested `origin` object).

**Inputs:**
| Parameter | Type | Schema |
| :--- | :--- | :--- |
| c1 | (1,:) struct | `circle.json` — array of `{radius, origin: {x, y}}` |
| c2 | (1,:) struct | `circle.json` — same as c1 |

**Output:** Logical matrix `tf(M,N)` where `tf(i,j)` is true if `c1(i)` intersects `c2(j)`.

### analyzeBeam

Analyzes a simply-supported beam under load. Demonstrates a schema with two levels of nesting (`beam_spec.cross_section.width`).

**Inputs:**
| Parameter | Type | Schema |
| :--- | :--- | :--- |
| beam_spec | (1,:) struct | `beam_spec.json` — material, cross-section geometry and span |
| load_case | (1,:) struct | `load_case.json` — load type, magnitude and position |

**Output:** Struct with fields `max_stress_Pa`, `max_deflection_m`, `natural_frequency_Hz`, `second_moment_of_area_m4`, `cross_section_area_m2` and `summary`.

#### beam_spec structure (2 levels deep)

```
beam_spec
├── material
│   ├── youngs_modulus   (number, Pa)
│   └── density          (number, kg/m^3)
├── cross_section
│   ├── shape            (string: "rectangular" or "circular")
│   ├── width            (number, m — rectangular)
│   ├── height           (number, m — rectangular)
│   └── diameter         (number, m — circular)
└── length               (number, m)
```

#### load_case structure (flat)

```
load_case
├── type        (string: "point" or "distributed")
├── magnitude   (number, N or N/m)
└── position    (number, m from left support — point loads only)
```

## Build and Deploy

Each tool is built into its own MCP server:

```MATLAB
% Build the circles tool
ctf1 = prodserver.mcp.build("circlesIntersect", ...
    wrapper="None", ...
    archive="Circles", ...
    folder="./deploy");

% Build the beam analysis tool
ctf2 = prodserver.mcp.build("analyzeBeam", ...
    wrapper="None", ...
    archive="BeamAnalysis", ...
    folder="./deploy");

% Deploy both
endpoint1 = prodserver.mcp.deploy(ctf1, "localhost", 9910);
endpoint2 = prodserver.mcp.deploy(ctf2, "localhost", 9910);
```

## Test the Tools

### Circle Intersection

```MATLAB
c1 = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
c2 = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));

tf = prodserver.mcp.call(endpoint1, "circlesIntersect", c1, c2)
tf =
  logical
   1
```

### Beam Analysis

```MATLAB
beam = struct( ...
    'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
    'cross_section', struct('shape', 'rectangular', ...
        'width', 0.05, 'height', 0.1), ...
    'length', 3.0);

load = struct('type', 'point', 'magnitude', 5000, 'position', 1.5);

result = prodserver.mcp.call(endpoint2, "analyzeBeam", beam, load)
result =
  struct with fields:
          max_stress_Pa: 4.5000e+07
       max_deflection_m: 2.1094e-04
    natural_frequency_Hz: 57.34
    ...
```

## How Schemas Help the LLM

Without `%#schema`, the LLM sees this tool definition for `analyzeBeam`:

```json
{ "beam_spec": { "type": "object" }, "load_case": { "type": "object" } }
```

It has no way to know what fields to provide. With `%#schema`, the definition includes:

```json
{
    "beam_spec": {
        "type": "object",
        "properties": {
            "material": {
                "type": "object",
                "properties": {
                    "youngs_modulus": { "type": "number", "description": "Young's modulus in Pascals" },
                    "density": { "type": "number", "description": "Density in kg/m^3" }
                }
            },
            ...
        }
    }
}
```

The LLM can now construct a valid call autonomously, without asking the user for the struct layout.
