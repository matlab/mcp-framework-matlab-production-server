# Structured Data with Schemas

Build MCP tools that accept struct parameters described with the `%#schema` pragma. Without schema annotations, an LLM sees only `"type": "object"` and cannot construct valid inputs. With schemas, the full field structure is exposed.

## The Tools

### circlesIntersect

Tests whether any circles in two lists overlap. Schema describes an array of objects each with a nested `origin` struct.

```MATLAB
function tf = circlesIntersect(c1, c2)
    arguments
        c1 (1,:) struct  %#schema circle.json
        c2 (1,:) struct  %#schema circle.json
    end
```

### analyzeBeam

Analyzes a simply-supported beam under load. Schema describes two levels of nesting (`beam_spec.cross_section.width`).

```MATLAB
function result = analyzeBeam(beam_spec, load_case)
    arguments
        beam_spec (1,:) struct  %#schema beam_spec.json
        load_case (1,:) struct  %#schema load_case.json
    end
```

## Build and Deploy

Each tool is built into its own server:
```MATLAB
ctf1 = prodserver.mcp.build("circlesIntersect", ...
    wrapper="None", archive="Circles", folder="./deploy");
ctf2 = prodserver.mcp.build("analyzeBeam", ...
    wrapper="None", archive="BeamAnalysis", folder="./deploy");

endpoint1 = prodserver.mcp.deploy(ctf1, "localhost", 9910);
endpoint2 = prodserver.mcp.deploy(ctf2, "localhost", 9910);
```

## Verify

```MATLAB
prodserver.mcp.ping(endpoint1)
prodserver.mcp.ping(endpoint2)
```

## Test with MCP Protocol

Circle intersection:
```MATLAB
c1 = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
c2 = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));

tf = prodserver.mcp.call(endpoint1, "circlesIntersect", c1, c2)
tf =
  logical
   1
```

Beam analysis:
```MATLAB
beam = struct( ...
    'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
    'cross_section', struct('shape', 'rectangular', 'width', 0.05, 'height', 0.1), ...
    'length', 3.0);
load = struct('type', 'point', 'magnitude', 5000, 'position', 1.5);

result = prodserver.mcp.call(endpoint2, "analyzeBeam", beam, load)
result =
  struct with fields:
          max_stress_Pa: 4.5000e+07
       max_deflection_m: 2.1094e-04
    natural_frequency_Hz: 57.34
```

## Connect an MCP Client

```json
{
  "mcpServers": {
    "Circles": {
      "url": "http://localhost:9910/Circles/mcp",
      "type": "http"
    },
    "BeamAnalysis": {
      "url": "http://localhost:9910/BeamAnalysis/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Do a circle at the origin with radius 10 and a circle at (8, 0) with radius 5 overlap?

> Analyze a 3-meter steel beam (E = 200 GPa, density 7800 kg/m^3) with a rectangular cross-section 50 mm wide by 100 mm tall under a 5 kN point load at the center.

The LLM constructs the nested struct inputs using the schema from the tool definition.

--- Copyright 2026 The MathWorks, Inc. ---
