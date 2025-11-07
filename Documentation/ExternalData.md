# Externalize Data Sources and Sinks
Passing even moderate amounts of floating point data as text through an LLM consumes a considerable 
amount of tokens. And it's very slow. Passing scalars or small strings to and from MCP tools isn't
a problem, but most interesting MATLAB functions accept or return arrays of numeric or structured data.
Managing this type of data in external sources and sinks conserves tokens and improves performance. MCP Framework uses data marshaling wrapper functions to externalize function inputs and outputs.

For example, consider an MCP tool that removes periodic noise from a signal:
```MATLAB
function clean = cleanSignal(noisy,period)
% cleanSignal Remove periodic noise from a signal using a Butterworth notch
% filter.
```
`cleanSignal` processes the input signal `noisy` with a Butterworth notch filter centered at `period` Hz 
to produce the output signal `clean`. `noisy` and `clean` are vectors of floating point numbers. `period` 
is a scalar. 

To make `cleanSignal` into an effective MCP tool, the signals `noisy` and `clean` must be externalized.
Locations for external data sources and sinks are specified by URLs. Currently, MCP Framework 
only supports the `file:` scheme. Both Linux and Windows file paths are supported.

## Automatically Generated Marshaling Function
MCP Framework can examine your MATLAB function and automatically generate a simple marshaling wrapper.
The generator externalizes all non-scalar function arguments. To enable automatic generation, you must 
use [`argument` blocks](https://www.mathworks.com/help/matlab/input-and-output-arguments.html)
to indicate which of your inputs and outputs are scalars. 

The `cleanSignal` function contains these argument blocks:
```MATLAB
    arguments (Input)
        noisy double        % Noisy signal
        period (1,1) double % Period (frequency) of the noise
    end
	
    arguments (Output)
        clean double % Signal with periodic noise removed.
    end
```
`period` has an explicit size of `(1,1)`, clearly indicating it is a scalar. The generator assumes the
other arguments are non-scalar, externalizes them and creates this wrapper function:

```MATLAB
function cleanSignalMCP(noisyURL, period, cleanURL)
% cleanSignalMCP Wrapper for cleanSignal function
    arguments (Input)
        noisyURL string % URL pointing to non-scalar input 'noisy' (double array)
        period (1,1) double
        cleanURL string % URL where the non-scalar output 'clean' (double array) is to be saved
    end
	
	noisy = deserialize(marshaller, noisyURL);
    % Call the actual cleanSignal function
    clean = cleanSignal(noisy{1}, period);
    serialize(marshaller, cleanURL, {clean});
end
```
MCP Framework has performed three transformations:
1. The input `noisy` has become the external data source `noisyURL`.
2. The output `clean` has become the external data sink `cleanURL`.
3. Moved all externalized data sinks (outputs) to the end of the input argument list.
The last transformation is required to allow the client (typically an MCP client) to specify the location of the output
data sink.

The original function is called with a vector and a scalar and returns a vector.
```MATLAB
noisy = ...
period = 60;

clean = cleanSignal(noisy, period)
```
The generated wrapper (and hence, the MCP tool) is called with an input URL, an input scalar and an output URL.
```MATLAB
noisyURL = "file:/data/source/openloopVoltage.csv";
period = 60;
cleanURL = "file:/data/sink/cleanloopVoltage.csv";

cleanSignal(noisyURL, period, cleanURL)
```

## Writing Your Own Marshaling Function
If the data source is more complex than a vector or matrix of numbers, you may need 
to write your own marshaling function. For example, the automatically generated 
marshaling function cannot process a CSV file containing a table of observations. It
isn't clear how to treat individual columns. Any situation that requires logic or 
the use of MATLAB's `ImportOptions` currently requires a custom marshaling function.

Since the marshaling function is the outward-facing interface of the MCP tool, 
annotating it with argument blocks and a clear, descriptive comment allows MCP
Framework to automatically generate the MCP tool definition.

The `plotTrajectoriesMCP` function externalizes its first input, `quakeData`, 
which it deserializes using `readtable`. `plotTrajectories` has no output parameters,
as it outputs a JPEG image file, the location of which is already an input (and thus
does not need further externalization).

```MATLAB
function plotTrajectoriesMCP(quakeURL,sampleRate, correction,start,stop,plotURL)
%plotTrajectoriesMCP Generate a 3x3 plot of trajectories from 3-axis 
%seismometer data. Plot each axis against each other. On the diagonal place
%histograms of the data from each axis. 

    arguments (Input)
        quakeURL string   % file: URL containing a table of uncorrected 3-axis seismometer accelerations
        sampleRate double % Seismometer sample rate in Hertz
        correction double % Instrument correction: apply to quakeData
        start double   % Start offset, in seconds, for trajectory data
        stop double    % Stop offset, in seconds, for trajectory data
        plotURL string % file: URL to save the plot into.
    end

    quakeFile = prodserver.mcp.io.uri.File.FileURI2Path(quakeURL);
    qd = readtable(quakeFile);
    plotFile = prodserver.mcp.io.uri.File.FileURI2Path(plotURL);
    plotTrajectories(qd,sampleRate,correction,start,stop,plotFile);
  
end
```

# Marshaling Utilities

Classes in the `prodserver.mcp.io` namespace manage data marshaling. The classes
documented here are intended for public use. If you are writing your own marshaling 
functions you may find them helpful.

## MarshallURI
`prodserver.mcp.io.MarshallURI` provides a high-level interface for marshaling data
using multiple URI schemes. Schemes are defined in the `uri` folder. `MarshallURI` scans
the `uri` folder on construction. Define new schemes by adding new subclasses of `Scheme` 
to the `uri` folder.

| Method  | Description  | Example | 
| :---    |  :---        | :---    |
| MarshallURI | Constructor. | `MarshallURI()` |
| deserialize | Read data from a source. | `data = deserialize(marshaller, url)` |
| exist | Does the source or sink exist? | `tf = exist(marshaller, url)` |
| serialize | Write data to a sink. | `serialize(marshaller, url, data)` |

## uri.File
`prodserver.mcp.io.uri.File` implements the `file:` scheme.

| Method  | Description  |
| :---    |  :---        |
| FileURI2Path | Static method to extract a file system path from a `file:` scheme URL. |
