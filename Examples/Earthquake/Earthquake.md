# Analyze Earthquake Data

This example creates an MCP tool to analyze and display earthquake data. 
The data are courtesy of Joel Yellin at the Charles F. Richter Seismological Laboratory, University of California, Santa Cruz. For a deeper look at the data see this [tutorial](https://www.mathworks.com/help/matlab/matlab_prog/loma-prieta-earthquake.html) on MATLAB timetables.

`plotTrajectories` generates a 3x3 plot of trajectories from 3-axis seismometer data by plotting each axis against each other. The diagonal has histograms of the data from each axis. The plot is saved as a JPEG file.

`plotTrajectories` requires a custom MCP tool wrapper function. The 1989 Loma Prieta earthquake data is stored in a table, which is best imported by the `readtable` function, rather than the default `readmatrix`. The wrapper function also externalizes the two largest arguments: the input earthquake data and the output JPEG plot file.

The original `plotTrajectories` function accepts the earthquake data as a MATLAB table. This table is large. Passing that much data through an LLM consumes many tokens and takes a long time. Far better to pass only the location of any large input and output data and have the wrapper function manage marshalling.
```MATLAB
function plotTrajectories(quakeData,sampleRate,correction,start,stop,plotFile)
    arguments
        quakeData   % Table of uncorrected 3-axis seismometer accelerations
        sampleRate  % Seismometer sample rate in Hertz
        correction  % Instrument correction: apply to quakeData
        start       % Start offset, in seconds, for trajectory data
        stop        % Stop offset, in seconds, for trajectory data
        plotFile    % Name of the file to save the plot into
    end
```

The wrapper function takes *location* of the earthquake data, as a `file:` URL. And it requires the location of the output JPEG image be a `file:` URL as well.
```MATLAB
function [status,msg] = plotTrajectoriesMCP(quakeURL,sampleRate, correction,start,stop,plotURL)
```

Before creating the MCP tool, test `plotTrajectories` on the earthquake data in MATLAB. This creates the 3x3 JPEG plot `qt.jpg` in the current folder. 
```MATLAB
quakeData = readtable("quakeData.csv");
plotTrajectories(quakeData,200,0.098,8,15,"qt.jpg");
```
On most systems you can open the JPEG image to view the plot by double-clicking on the file. Or display the plot in MATLAB:
```MATLAB
img = imread("qt.jpg");
figure
imshow(img);
```

# Package and Deploy MCP Tool
Publish `plotTrajectories` as an MCP tool by building it into a deployable archive and uploading that archive to an instance of MATLAB Production Server.
```MATLAB
ctf = prodserver.mcp.build("plotTrajectories",wrapper="plotTrajectoriesMCP.m")
endpoint = prodserver.mcp.deploy(ctf,"localhost",9910)
```
The MCP tool definition is automatically generated from the handwritten wrapper function. The file `plotTrajectories.json` in the example folder contains the automatically generated MCP tool definition.

# Verify Deployment
To quickly verify that the MCP tool is available, use the `ping` or `exist` functions.
* `ping` is more general and determines if an MCP server is accepting requests.
* `exist` is more specific and lets you inquire if a given server supports a particular tool.

```MATLAB
% Is the server awake?
available = prodserver.mcp.ping(endpoint)

% Does the tool exist on the server?
tf = prodserver.mcp.exist(endpoint, "plotTrajectories", "Tool")
```

# Test Deployed MCP Tool

Use `prodserver.mcp.call` to call the deployed MCP Tool using the JSONRPC 2.0 protocol, just as an AI agent will. If this call succeeds, you can be confident that large language models will be able to access this tool. Note that the interface to the tool is the [wrapper function](../../Documentation/ExternalData.md) -- which takes a URL for the input earthquake data and the output plot file. 

```MATLAB
% Construct paths (and URLs) for input and output files.
quakeData = "file:" + fullfile(dataFolder,"quakeData.csv");
plotFile = fullfile(dataFolder,"qTrajectories.jpg");
plotURL = "file:" + plotFile;

% Call the tool on the server using MCP protocol
[status,msg] = prodserver.mcp.call(endpoint, "plotTrajectories", quakeData, 200,0.098,8,15, ...
    plotURL)
```