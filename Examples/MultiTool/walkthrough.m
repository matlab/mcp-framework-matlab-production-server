%% Multi-Tool Fractal Server
% Build a single MCP server hosting seven fractal-generation tools with
% renamed tool names.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if exist("mpsServer","var") == false || isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Build the Server
% Specify tool names (what clients see) and function names (MATLAB
% implementations). The arrays must be the same size.

tool = ["twinDragon", "chaos", "snowflake", "mandelbrot", ...
    "dragonDraw", "turtleGraphic", "renderPointCloud"];

fcn = ["chaosdragon", "chaosfractal", "snowflake", ...
    "mandelbrot", "renderDragon", "drawvector", "drawpoints"];
t= tic;

fprintf(1,"Start build %s %f.2\n","Fractalizer",round(toc(t),2));
ctf = prodserver.mcp.build(fcn, tool=tool, archive="Fractalizer", folder="./deploy");
fprintf(1,"Finish build %s %f.2\n","Fractalizer",round(toc(t),2));

%% Deploy to MATLAB Production Server

fprintf(1,"Start deploy %s %f.2\n",ctf,round(toc(t),2));
endpoint = prodserver.mcp.deploy(ctf, mpsServer);
fprintf(1,"Finish deploy %s %f.2\n",endpoint,round(toc(t),2));

%% Verify Deployment
% List all seven tools on the server.

fprintf(1,"Start ping %s %f.2\n",endpoint,round(toc(t),2));
prodserver.mcp.ping(endpoint)
fprintf(1,"End ping %s %f.2\n",endpoint,round(toc(t),2));

fprintf(1,"Start list %s %f.2\n",endpoint,round(toc(t),2));
tools = prodserver.mcp.list(endpoint, "Tool");
fprintf(1,"End list %s %f.2\n",endpoint,round(toc(t),2));

cellfun(@(t) t.name, tools, 'UniformOutput', false)

%% Generate a Twin Dragon Fractal
% Use the |twinDragon| tool to generate 200,000 fractal points.

thisFolder = fileparts(mfilename("fullpath"));
% Allow override on machines without graphics hardware acceleration
if exist("N","var") == false || isempty(N)
    N = 200000;
end
dragonXY = fullfile(thisFolder, "TwinDragonXY.mat");
dragonURL = "file:" + replace(dragonXY, filesep, "/");
fprintf(1,"Start Generate %s %f.2\n",endpoint,round(toc(t),2));
prodserver.mcp.call(endpoint, "twinDragon", N, "dragonURL", dragonURL);
fprintf(1,"End Generate %s %f.2\n",endpoint,round(toc(t),2));

%% Render the Fractal as an Image
% Chain the |dragonDraw| tool to render the points into a JPEG.

jpg = fullfile(thisFolder, "TwinDragonImage.jpg");
color1 = "#FF0000";
color2 = "#0000FF";
dragonSizeURL = "file:" + replace(fullfile(thisFolder, "TwinDragonSize.mat"), filesep, "/");
fprintf(1,"Start Render %s %f.2\n",jpg,round(toc(t),2));
prodserver.mcp.call(endpoint, "dragonDraw", dragonURL, color1, color2, jpg, "szURL", dragonSizeURL);
fprintf(1,"End Render %s %f.2\n",jpg,round(toc(t),2));

disp("Open figure")
figure
imshow(imread(jpg));
title("Twin Dragon Fractal via MCP");
disp("Figure complete")

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/Fractalizer/mcp
%
% Then try this prompt:
%
%   Generate a twin-dragon fractal with 500,000 points and render it in red
%   and blue. Save the image as dragon.jpg.


