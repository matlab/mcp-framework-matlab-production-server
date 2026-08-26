# Material Properties and Engineering Calculations

This example demonstrates how MCP Resources enhance the usability of MCP tools by providing data that an LLM can discover and read before calling tools.

The server hosts:
- **Two tools**: `calculateBeamStress` and `calculateThermalResistance`
- **Five resources**: a material catalog and properties for four engineering materials

Without resources, an LLM must either ask the user for material constants (poor user experience) or hallucinate values (dangerous for engineering). With resources, the LLM reads exact material properties from the server itself and passes them directly to the tools.

## How Resources Help

Consider the question: "Will a 2-meter aluminum beam support a 10kN point load?"

**Without resources**, the LLM must:
1. Ask the user: "What is the Young's modulus and yield strength of aluminum 6061-T6?"
2. Or guess values — potentially incorrectly.

**With resources**, the LLM can:
1. Read `mcp://materials/catalog` to discover available materials.
2. Read `mcp://materials/aluminum_6061` to get exact property values.
3. Call `calculateBeamStress` with verified data.
4. Report a trustworthy result.

The server is self-contained and usable without domain expertise from the user. 

And adding new materials to the solution is simple: updaate the resource catalog only, no code changes required.

When connected to an MCP client (Claude Desktop, Claude Code, VS Code with Copilot), an LLM uses this server as follows:

1. **Discover**: reads `mcp://materials/catalog` to see available materials.
2. **Research**: reads a specific material resource to get exact property values.
3. **Calculate**: calls `calculateBeamStress` or `calculateThermalResistance` with verified values.
4. **Report**: presents results to the user with confidence in the input data.

This pattern -- resource lookup followed by informed tool call -- applies broadly to any domain where tools require reference data: sensor calibration, unit conversions, simulation parameters, and more.

## Example Usage

```MATLAB
% Beam stress: 2m aluminum beam, 50mm x 100mm, 10kN load
result = prodserver.mcp.call(endpoint, "calculateBeamStress", ...
    10000, 2.0, 0.05, 0.1, 68.9e9, 276e6)

result = 
  struct with fields:
       max_stress_Pa: 6.0000e+07
    max_deflection_m: 1.7125e-03
       safety_factor: 4.6000
              status: "PASS"
             summary: "Beam stress 60 MPa (yield 276 MPa, SF=4.60). Max deflection 1.71 mm."
```

```MATLAB
% Thermal resistance: 3mm copper plate, 0.04 m^2, 100C to 25C
result = prodserver.mcp.call(endpoint, "calculateThermalResistance", ...
    0.003, 0.04, 388, 100, 25)

result = 
  struct with fields:
    thermal_resistance_KperW: 1.9330e-04
        heat_transfer_rate_W: 3.8800e+05
          heat_flux_Wperm2: 9.7000e+06
     midpoint_temperature_C: 62.5000
                     summary: "Heat flow: 3.88e+05 W through 3 mm plate (0.04 m^2). ..."
```

## Build and Deploy

The function `buildMaterialsServer` builds and optionally deploys the server. Supply `host` or `port` to trigger deployment to a running MATLAB Production Server instance.

```MATLAB
% Build only (no deployment)
ctf = buildMaterialsServer();

% Build and deploy to localhost:9910
[ctf, endpoint] = buildMaterialsServer(host="localhost");

% Build and deploy to a specific host and port
[ctf, endpoint] = buildMaterialsServer(host="myserver", port=9920);
```

Or build step-by-step:

```MATLAB
% Define resources (shown here for one material; see buildMaterialsServer.m for all)
aluminum = struct( ...
    'uri', 'mcp://materials/aluminum_6061', ...
    'contents', fullfile(pwd, "aluminum_6061.json"), ...
    'name', 'aluminum_6061', ...
    'title', 'Aluminum 6061-T6', ...
    'description', 'Mechanical and thermal properties of Aluminum 6061-T6 alloy.', ...
    'mimeType', 'application/json');

% Build the server with tools and resources
fcn = ["calculateBeamStress", "calculateThermalResistance"];
ctf = prodserver.mcp.build(fcn, ...
    archive="Materials", ...
    resource=aluminum, ...
    folder="./deploy");

% Deploy
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

## Tool and Resource Reference

The tools are MATLAB functions.

### calculateBeamStress

Calculates maximum bending stress, deflection and safety factor for a simply-supported rectangular beam under a central point load. Uses Euler-Bernoulli beam theory.

**Inputs:**
| Parameter | Type | Units | Description |
| :--- | :--- | :--- | :--- |
| load | double | N | Applied force at beam center |
| length | double | m | Beam span |
| width | double | m | Cross-section width |
| height | double | m | Cross-section height |
| youngs_modulus | double | Pa | Material stiffness (from resource) |
| yield_strength | double | Pa | Material yield point (from resource) |

**Outputs:**
| Field | Type | Description |
| :--- | :--- | :--- |
| max_stress_Pa | double | Maximum bending stress at midspan |
| max_deflection_m | double | Maximum deflection at midspan |
| safety_factor | double | Ratio of yield strength to maximum stress |
| status | string | "PASS" if safety_factor >= 1, "FAIL" otherwise |
| summary | string | Human-readable result summary |

### calculateThermalResistance

Calculates steady-state heat transfer through a flat plate using Fourier's law of conduction.

**Inputs:**
| Parameter | Type | Units | Description |
| :--- | :--- | :--- | :--- |
| thickness | double | m | Plate thickness |
| area | double | m^2 | Cross-sectional area for heat flow |
| thermal_conductivity | double | W/(m*K) | Material thermal conductivity (from resource) |
| T_hot | double | C | Hot-side boundary temperature |
| T_cold | double | C | Cold-side boundary temperature |

**Outputs:**
| Field | Type | Description |
| :--- | :--- | :--- |
| thermal_resistance_KperW | double | Conductive thermal resistance |
| heat_transfer_rate_W | double | Total heat flow rate |
| heat_flux_Wperm2 | double | Heat flow per unit area |
| midpoint_temperature_C | double | Temperature at plate midpoint |
| summary | string | Human-readable result summary |

### Resources

Each resource is a JSON document containing material properties.

| URI | Description |
| :--- | :--- |
| `mcp://materials/catalog` | Index of all materials with one-line summaries |
| `mcp://materials/aluminum_6061` | Aluminum 6061-T6 mechanical and thermal properties |
| `mcp://materials/steel_304` | Stainless Steel 304 properties |
| `mcp://materials/titanium_ti6al4v` | Titanium Ti-6Al-4V properties |
| `mcp://materials/copper_c110` | Copper C110 (ETP) properties |

Each material resource has this structure:
```json
{
  "name": "Aluminum 6061-T6",
  "category": "Aluminum Alloy",
  "properties": {
    "density": {"value": 2700, "units": "kg/m^3"},
    "youngs_modulus": {"value": 68.9e9, "units": "Pa"},
    "yield_strength": {"value": 276e6, "units": "Pa"},
    "ultimate_tensile_strength": {"value": 310e6, "units": "Pa"},
    "poissons_ratio": {"value": 0.33, "units": "dimensionless"},
    "thermal_conductivity": {"value": 167, "units": "W/(m*K)"},
    "specific_heat": {"value": 896, "units": "J/(kg*K)"},
    "thermal_expansion_coefficient": {"value": 23.6e-6, "units": "1/K"}
  }
}
```

--- Copyright 2026 The MathWorks, Inc. ---
