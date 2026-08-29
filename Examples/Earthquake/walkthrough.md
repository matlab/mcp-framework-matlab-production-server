# Earthquake Trajectory Analysis

Build an MCP tool that generates 3x3 trajectory plots from 3-axis seismometer data. This example demonstrates a custom wrapper function that imports table data and externalizes both a large input table and a JPEG output file.

## The Function

`plotTrajectories` accepts earthquake acceleration data as a MATLAB table and produces a JPEG plot of axis-vs-axis trajectories with histograms on the diagonal.

```MATLAB
function plotTrajectories(quakeData, sampleRate, correction, start, stop, plotFile)
    arguments
        quakeData   % Table of uncorrected 3-axis seismometer accelerations
        sampleRate  % Seismometer sample rate in Hertz
        correction  % Instrument correction factor
        start       % Start offset in seconds
        stop        % Stop offset in seconds
        plotFile    % File path for the output JPEG
    end
```

Test it locally:
```MATLAB
quakeData = readtable("quakeData.csv");
plotTrajectories(quakeData, 200, 0.098, 8, 15, "qt.jpg");
imshow(imread("qt.jpg"));
```

## Why a Custom Wrapper?

The earthquake data is a large table best read with `readtable` (not the default `readmatrix`). The wrapper function `plotTrajectoriesMCP` accepts file URLs for the input data and output plot, and manages the marshalling.

```MATLAB
function [status,msg] = plotTrajectoriesMCP(quakeURL, sampleRate, correction, start, stop, plotURL)
    marshaller = prodserver.mcp.io.MarshallURI();
    noisy = deserialize(marshaller, quakeURL);
    plotTrajectories(noisy{1}, sampleRate, correction, start, stop, plotURL);
end
```

## Build

```MATLAB
ctf = prodserver.mcp.build("plotTrajectories", wrapper="plotTrajectoriesMCP.m");
```

## Deploy

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

## Verify

```MATLAB
prodserver.mcp.ping(endpoint)
ans =
    true

prodserver.mcp.exist(endpoint, "plotTrajectories", "Tool")
ans =
    true
```

## Test with MCP Protocol

```MATLAB
quakeData = "file:" + fullfile(pwd, "quakeData.csv");
plotFile = fullfile(pwd, "qTrajectories.jpg");
plotURL = "file:" + plotFile;

[status, msg] = prodserver.mcp.call(endpoint, "plotTrajectories", ...
    quakeData, 200, 0.098, 8, 15, plotURL)
```

## Connect an MCP Client

```json
{
  "mcpServers": {
    "plotTrajectories": {
      "url": "http://localhost:9910/plotTrajectories/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Plot the earthquake trajectory data from quakeData.csv. The seismometer sample rate is 200 Hz, the instrument correction factor is 0.098, and I want to see the data between 8 and 15 seconds. Save the plot as trajectories.jpg.

The LLM constructs file URLs for the CSV input and JPEG output, then calls `plotTrajectories` with the numeric parameters.

--- Copyright 2025-2026 The MathWorks, Inc. ---
