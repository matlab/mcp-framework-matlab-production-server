# Multi-Tool Fractal Server

Build a single MCP server hosting seven fractal-generation tools. This example demonstrates multi-tool servers with renamed tools (tool names different from their MATLAB function names).

## The Tools

| Tool Name | MATLAB Function | Description |
| :--- | :--- | :--- |
| twinDragon | chaosdragon | Generate points of the twin-dragon fractal |
| chaos | chaosfractal | Generate chaos game fractal points |
| snowflake | snowflake | Generate Koch snowflake outline vectors |
| mandelbrot | mandelbrot | Generate Mandelbrot set |
| dragonDraw | renderDragon | Render twin-dragon points as a JPEG image |
| turtleGraphic | drawvector | Draw vector paths using turtle graphics |
| renderPointCloud | drawpoints | Produce a JPEG from 2D point coordinates |

## Build

Specify both `tool` names (what clients see) and `fcn` names (which MATLAB functions implement them). The arrays must be the same size.

```MATLAB
tool = ["twinDragon", "chaos", "snowflake", "mandelbrot", ...
    "dragonDraw", "turtleGraphic", "renderPointCloud"];

fcn = ["chaosdragon", "chaosfractal", "snowflake", ...
    "mandelbrot", "renderDragon", "drawvector", "drawpoints"];

ctf = prodserver.mcp.build(fcn, tool=tool, archive="Fractalizer", folder="./deploy");
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

tools = prodserver.mcp.list(endpoint, "Tool");
{tools.name}'
```

## Test with MCP Protocol

Generate a twin-dragon fractal and render it as an image. The tools chain together: `twinDragon` produces points, `dragonDraw` renders them.

```MATLAB
N = 200000;
dragonXY = fullfile(pwd, "TwinDragonXY.mat");
dragonURL = "file:" + replace(dragonXY, filesep, "/");

prodserver.mcp.call(endpoint, "twinDragon", N, dragonURL);

jpg = fullfile(pwd, "TwinDragonImage.jpg");
dragonSizeURL = "file:" + replace(fullfile(pwd, "TwinDragonSize.mat"), filesep, "/");

prodserver.mcp.call(endpoint, "dragonDraw", dragonURL, "#FF0000", "#0000FF", jpg, dragonSizeURL);
imshow(imread(jpg));
```

## Connect an MCP Client

```json
{
  "mcpServers": {
    "Fractalizer": {
      "url": "http://localhost:9910/Fractalizer/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Generate a twin-dragon fractal with 500,000 points and render it in red and blue. Save the image as dragon.jpg.

The LLM chains two tool calls: first `twinDragon` to generate the points, then `dragonDraw` to render them into an image.

--- Copyright 2025-2026 The MathWorks, Inc. ---
