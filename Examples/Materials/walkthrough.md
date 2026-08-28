# Material Properties and Engineering Calculations

Build a multi-tool MCP server that combines engineering calculation tools with MCP Resources containing material property data. An LLM can discover materials, read their properties, and pass exact values to the calculation tools without hallucinating physical constants.

## The Tools

The server hosts two tools:
- **calculateBeamStress** — bending stress, deflection, and safety factor for a simply-supported beam
- **calculateThermalResistance** — steady-state heat transfer through a flat plate

And five resources providing material property data for aluminum, steel, titanium, and copper.

## How Resources Help

Without resources, an LLM must ask the user for material constants or guess them. With resources, the LLM reads exact property values from the server itself:

1. Read `mcp://materials/catalog` to discover available materials
2. Read `mcp://materials/aluminum_6061` to get exact property values
3. Call `calculateBeamStress` with verified data
4. Report a trustworthy result

## Build and Deploy

The function `buildMaterialsServer` packages both tools and all resources into a single server.

```MATLAB
[ctf, endpoint] = buildMaterialsServer(host="localhost");
```

Or build step-by-step:
```MATLAB
fcn = ["calculateBeamStress", "calculateThermalResistance"];
ctf = prodserver.mcp.build(fcn, ...
    archive="Materials", ...
    resource=resources, ...
    folder="./deploy");

endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

## Verify

```MATLAB
prodserver.mcp.ping(endpoint)
ans =
    true

prodserver.mcp.exist(endpoint, "calculateBeamStress", "Tool")
ans =
    true
```

## Test with MCP Protocol

Beam stress: 2 m aluminum beam, 50 mm x 100 mm cross-section, 10 kN point load.
```MATLAB
result = prodserver.mcp.call(endpoint, "calculateBeamStress", ...
    10000, 2.0, 0.05, 0.1, 68.9e9, 276e6)
result =
  struct with fields:
       max_stress_Pa: 6.0000e+07
    max_deflection_m: 1.7125e-03
       safety_factor: 4.6000
              status: "PASS"
```

Thermal resistance: 3 mm copper plate, 0.04 m^2, 100 C to 25 C.
```MATLAB
result = prodserver.mcp.call(endpoint, "calculateThermalResistance", ...
    0.003, 0.04, 388, 100, 25)
result =
  struct with fields:
    thermal_resistance_KperW: 1.9330e-04
        heat_transfer_rate_W: 3.8800e+05
```

## Connect an MCP Client

```json
{
  "mcpServers": {
    "Materials": {
      "url": "http://localhost:9910/Materials/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Will a 2-meter aluminum 6061-T6 beam with a 50 mm x 100 mm rectangular cross-section support a 10 kN point load at its center? What is the safety factor?

The LLM reads the material catalog, looks up aluminum properties, and calls `calculateBeamStress` with exact values from the resource.

--- Copyright 2026 The MathWorks, Inc. ---
