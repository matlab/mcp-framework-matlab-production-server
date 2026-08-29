%% Material Properties and Engineering Calculations
% Build a multi-tool MCP server with MCP Resources containing material
% property data. An LLM discovers materials, reads their properties, and
% passes exact values to calculation tools.

% Copyright 2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Build and Deploy
% |buildMaterialsServer| packages both tools and all material resources
% into a single MCP server.

[ctf, endpoint] = buildMaterialsServer(host=mpsServer);

%% Verify Deployment

prodserver.mcp.ping(endpoint)
prodserver.mcp.exist(endpoint, "calculateBeamStress", "Tool")
prodserver.mcp.exist(endpoint, "calculateThermalResistance", "Tool")

%% List Available Tools
% Query the server for its tool definitions.

tools = prodserver.mcp.list(endpoint, "Tool");
cellfun(@(t) t.name, tools, 'UniformOutput', false)

%% Test Beam Stress Calculation
% 2 m aluminum beam, 50 mm x 100 mm, 10 kN central point load.
% Material properties from aluminum 6061-T6: E = 68.9 GPa, Sy = 276 MPa.

result = prodserver.mcp.call(endpoint, "calculateBeamStress", ...
    10000, 2.0, 0.05, 0.1, 68.9e9, 276e6)

%% Test Thermal Resistance Calculation
% 3 mm copper plate, 0.04 m^2 area, 100 C hot side, 25 C cold side.
% Material property from copper C110: k = 388 W/(m*K).

result = prodserver.mcp.call(endpoint, "calculateThermalResistance", ...
    0.003, 0.04, 388, 100, 25)

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/Materials/mcp
%
% Then try this prompt:
%
%   Will a 2-meter aluminum 6061-T6 beam with a 50 mm x 100 mm rectangular
%   cross-section support a 10 kN point load at its center? What is the
%   safety factor?
%
% The LLM reads the material catalog resource, looks up aluminum 6061
% properties, and calls calculateBeamStress with exact values.


