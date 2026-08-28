%% Structured Data with Schemas
% Build MCP tools that accept struct parameters described with the
% |%#schema| pragma, so LLMs can construct valid nested inputs.

% Copyright 2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server.
mpsServer = "http://localhost:9910";

%% Build and Deploy the Circles Tool
% |circlesIntersect| uses schema files to describe its struct parameters.

ctf1 = prodserver.mcp.build("circlesIntersect", ...
    wrapper="None", archive="Circles", folder="./deploy");
endpoint1 = prodserver.mcp.deploy(ctf1, mpsServer);

%% Build and Deploy the Beam Analysis Tool
% |analyzeBeam| has two levels of struct nesting described by schemas.

ctf2 = prodserver.mcp.build("analyzeBeam", ...
    wrapper="None", archive="BeamAnalysis", folder="./deploy");
endpoint2 = prodserver.mcp.deploy(ctf2, mpsServer);

%% Verify Deployment

prodserver.mcp.ping(endpoint1)
prodserver.mcp.ping(endpoint2)

%% Test Circle Intersection
% Two circles: one at the origin (r=5) and one at (6,0) (r=3). They
% overlap because the distance between centers (6) is less than the sum of
% radii (8).

c1 = struct('radius', 5, 'origin', struct('x', 0, 'y', 0));
c2 = struct('radius', 3, 'origin', struct('x', 6, 'y', 0));

tf = prodserver.mcp.call(endpoint1, "circlesIntersect", c1, c2)

%% Test Beam Analysis
% 3 m steel beam, 50 mm x 100 mm rectangular cross-section, 5 kN point
% load at center.

beam = struct( ...
    'material', struct('youngs_modulus', 200e9, 'density', 7800), ...
    'cross_section', struct('shape', 'rectangular', 'width', 0.05, 'height', 0.1), ...
    'length', 3.0);
load = struct('type', 'point', 'magnitude', 5000, 'position', 1.5);

result = prodserver.mcp.call(endpoint2, "analyzeBeam", beam, load)

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/Circles/mcp
%   http://localhost:9910/BeamAnalysis/mcp
%
% Then try this prompt:
%
%   Analyze a 3-meter steel beam (E = 200 GPa, density 7800 kg/m^3) with a
%   rectangular cross-section 50 mm wide by 100 mm tall under a 5 kN point
%   load at the center. What is the maximum stress and deflection?


