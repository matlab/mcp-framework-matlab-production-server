%% Multi-Tool Fractal Server
% Build a single MCP server hosting seven fractal-generation tools with
% renamed tool names.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Build the Server
% Specify tool names (what clients see) and function names (MATLAB
% implementations). The arrays must be the same size.

tool = ["twinDragon", "chaos", "snowflake", "mandelbrot", ...
    "dragonDraw", "turtleGraphic", "renderPointCloud"];

fcn = ["chaosdragon", "chaosfractal", "snowflake", ...
    "mandelbrot", "renderDragon", "drawvector", "drawpoints"];

ctf = prodserver.mcp.build(fcn, tool=tool, archive="Fractalizer", folder="./deploy");

%% Deploy to MATLAB Production Server

endpoint = prodserver.mcp.deploy(ctf, mpsServer);

%% Verify Deployment
% List all seven tools on the server.

prodserver.mcp.ping(endpoint)
tools = prodserver.mcp.list(endpoint, "Tool");
cellfun(@(t) t.name, tools, 'UniformOutput', false)

%% Generate a Twin Dragon Fractal
% Use the |twinDragon| tool to generate 200,000 fractal points.

thisFolder = fileparts(mfilename("fullpath"));
N = 200000;
dragonXY = fullfile(thisFolder, "TwinDragonXY.mat");
dragonURL = "file:" + replace(dragonXY, filesep, "/");

prodserver.mcp.call(endpoint, "twinDragon", N, "dragonURL", dragonURL);

%% Render the Fractal as an Image
% Chain the |dragonDraw| tool to render the points into a JPEG.

jpg = fullfile(thisFolder, "TwinDragonImage.jpg");
color1 = "#FF0000";
color2 = "#0000FF";
dragonSizeURL = "file:" + replace(fullfile(thisFolder, "TwinDragonSize.mat"), filesep, "/");

prodserver.mcp.call(endpoint, "dragonDraw", dragonURL, color1, color2, jpg, "szURL", dragonSizeURL);

figure
imshow(imread(jpg));
title("Twin Dragon Fractal via MCP");

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/Fractalizer/mcp
%
% Then try this prompt:
%
%   Generate a twin-dragon fractal with 500,000 points and render it in red
%   and blue. Save the image as dragon.jpg.


