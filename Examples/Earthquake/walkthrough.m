%% Earthquake Trajectory Analysis
% Build an MCP tool that generates 3x3 trajectory plots from 3-axis
% seismometer data. Demonstrates a custom wrapper for table import and
% JPEG output.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if exist("mpsServer","var") == false || isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Test the Function Locally
% |plotTrajectories| reads earthquake data as a table and produces a 3x3
% trajectory plot saved as JPEG.

quakeData = readtable("quakeData.csv");
plotTrajectories(quakeData, 200, 0.098, 8, 15, "qt.jpg");

figure
imshow(imread("qt.jpg"));
title("Loma Prieta 1989 - Trajectory Plot");

%% Build the MCP Tool
% Use the custom wrapper |plotTrajectoriesMCP| which accepts file URLs for
% the large table input and JPEG output.

ctf = prodserver.mcp.build("plotTrajectories", wrapper="plotTrajectoriesMCP.m");

%% Deploy to MATLAB Production Server

endpoint = prodserver.mcp.deploy(ctf, mpsServer);

%% Verify Deployment

prodserver.mcp.ping(endpoint)
prodserver.mcp.exist(endpoint, "plotTrajectories", "Tool")

%% Test with MCP Protocol
% Call the tool using file URLs, just as an LLM would.

thisFolder = fileparts(mfilename("fullpath"));
quakeURL = "file:" + fullfile(thisFolder, "quakeData.csv");
plotFile = fullfile(thisFolder, "qTrajectories.jpg");
plotURL = "file:" + plotFile;

[status, msg] = prodserver.mcp.call(endpoint, "plotTrajectories", ...
    quakeURL, 200, 0.098, 8, 15, plotURL)

%% Display the Result

figure
imshow(imread(plotFile));
title("Trajectory Plot via MCP Tool");

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/plotTrajectories/mcp
%
% Then try this prompt:
%
%   Plot the earthquake trajectory data from quakeData.csv. The seismometer
%   sample rate is 200 Hz, the instrument correction is 0.098, and I want
%   to see the data between 8 and 15 seconds. Save the plot as
%   trajectories.jpg.


