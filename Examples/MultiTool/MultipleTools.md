
# Tools and the Server

An MCP server may host multiple tools. Build multi\-tool servers with MCP Framework by specifying multiple MATLAB functions to `prodserver.mcp.build`. Tools cannot be added to or removed from an existing server \-\- servers must be rebuilt to add or remove tools.

# Build Server with Seven Tools

By default, a tool has the same name as the MATLAB function that implements the tool. Optionally, tools may be given their own names. MCP clients interact with tool names, not MATLAB function names. This code specifies new names for five of the seven tools. Even though the `snowflake` and `mandelbrot` functions are not getting new names they still must have their tool names specified explicitly, since the `tool` and `fcn` inputs must be the same size.

```matlab
% Tool names -- the names used to call the tool. These are the names
% reported by prodserver.mcp.list.
tool = ["twinDragon", "chaos", "snowflake", "mandelbrot", ...
    "dragonDraw", "turtleGraphic", "renderPointCloud"];

% Functions that implement the tools. Each of these names must be a
% function on MATLAB's path.
fcn = ["chaosdragon", "chaosfractal", "snowflake", ...
    "mandelbrot", "renderDragon", "drawvector", "drawpoints"];

% Build the tools into a Swiss Army knife of a server. Specify a server
% name -- otherwise the server would have the same name as the first tool
% in the tool list.
server = "Fractalizer";
ctf = prodserver.mcp.build(fcn, tool=tool, archive=server, folder="./deploy")
```

```matlabTextOutput
ctf = "C:\work\MultiTool\deploy\Fractalizer.ctf"
```

# Deploy the Server

Having successfully built the server, deploy it to an instance of MATLAB Production Server. And then query the endpoint for the list of supported tools. The response to the query provides all the information required to invoke the tool: name, description and input and output schemas.

```matlab
endpoint = prodserver.mcp.deploy(ctf, "http://localhost:9910")
```

```matlabTextOutput
endpoint = "http://localhost:9910/Fractalizer/mcp"
```

```matlab
tools = prodserver.mcp.list(endpoint,"Tool")
```


```matlabTextOutput
tools = 8x1 cell
    {1x1 struct}
    {1x1 struct}
    {1x1 struct}
    {1x1 struct}
    {1x1 struct}
    {1x1 struct}
    {1x1 struct}
    {1x1 struct}
```

The eighth tool, `read_mcp_resource`, is the framework's own: `build` adds it to every server. Each cell holds a structure with `name`, `description`, `inputSchema`, `outputSchema` and `server` fields.


```matlab
toolNames = cellfun(@(t) t.name, tools, UniformOutput=false);
```
# Create and Display TwinDragon

Used together, the `twinDragon` and `dragonDraw` tools produce an image of the twin dragon fractal. `twinDragon` generates the points of the fractal and `dragonDraw` renders those points into a JPG image. 


The automatically added wrapper functions determine the interface used to call the tool. Typically wrapper functions externalize non\-scalar inputs and outputs into URL\-based data sources and sinks. This prevents large data sets from passing through the large language model, which makes tools faster and cheaper. 


Use the information returned by `prodserver.mcp.list` to view the externalized interface and call the tool.

```matlab
% Find the "twinDragon" tool in the list of tools. Look for a tool
% with the name "twinDragon".
tool = "twinDragon";
k = strcmp(tool,toolNames);

% Display the input parameters. There are two: N and dragonURL. The
% structure value of each describes the type and purpose of the input.
tools{k}.inputSchema.properties
```

```matlabTextOutput
ans = struct with fields:
            N: [1x1 struct]
    dragonURL: [1x1 struct]

```

```matlab
% N is a number specifying how many points the twin dragon fractal will
% contain.
tools{k}.inputSchema.properties.N
```

```matlabTextOutput
ans = struct with fields:
           type: 'number'
    description: 'Number of points in the resulting fractal.'

```

```matlab
% dragonURL is an output location, a URL which must be capable of receiving
% an Nx2 matrix of floating point numbers.
tools{k}.inputSchema.properties.dragonURL
```

```matlabTextOutput
ans = struct with fields:
           type: 'string'
    description: 'Nx2 matrix of fractal points. Each row is a single point. Column 1 is the X coordinates, column 2 the Y coordinates.'

```

```matlab
% Setup to generate a fractal with 200,000 points. Return the points in a 
% MAT-file, TwinDragonXY.mat, in an output folder in the current folder:
% the example's own folder may be read-only.
N = 200000;
out = fullfile(pwd,"output");
if ~isfolder(out), mkdir(out); end
dragonXY = fullfile(out,"TwinDragonXY.mat");
dragonURL = "file:" + replace(dragonXY,filesep,"/");

% Call the tool using the MCP protocol and check for success: the tool
% should create the MAT-file.
prodserver.mcp.call(endpoint,tool,N,"dragonURL",dragonURL);
success = exist(dragonXY,"file") == 2
```

These `file:` URLs name files on the server's machine: MATLAB Production Server reads and writes them itself. Building them from your own folder works when the server runs on your machine, or can reach that folder at the same path. For a remote server, see [URL Scheme](../../docs/concepts/wrapper-functions.md#url-scheme).

```matlabTextOutput
success = logical
   1

```

```matlab
% Use the information returned by prodserver.mcp.list to determine how to
% call the dragonDraw tool. Note the location of the JPG result is specified 
% by file path rather than by a URL. That's because the JPG location is a
% scalar string input to the original function and thus not subject to an
% externalizing transformation by the wrapper function.
tool = "dragonDraw";
k = strcmp(tool,toolNames);
tools{k}.inputSchema.properties
```

```matlabTextOutput
ans = struct with fields:
    dragonURL: [1x1 struct]
       color1: [1x1 struct]
       color2: [1x1 struct]
          jpg: [1x1 struct]
        szURL: [1x1 struct]

```

```matlab
% Setup to call a second tool, dragonDraw, to render the points of the
% fractal into a JPG image. 
jpg = fullfile(out,"TwinDragonImage.jpg");
color1 = "#FF0000";   % Red
color2 = "#0000FF";   % Blue
dragonSize = fullfile(out,"TwinDragonSize.mat");
dragonSizeURL = "file:" + replace(dragonSize,filesep,"/");

% Call the dragonDraw tool using the MCP protocol. Test for success by
% looking for the generated JPG file.
prodserver.mcp.call(endpoint,tool,dragonURL,color1,color2,jpg,"szURL",dragonSizeURL);
success = exist(jpg,"file") == 2
```

```matlabTextOutput
success = logical
   1

```

```matlab
% Display the generated image
figure
img = imread(jpg);
imshow(img);
```

![figure_0.png](MultipleTools_media/figure_0.png)

--- Copyright 2025-2026 The MathWorks, Inc. ---
