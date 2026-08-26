# Building MCP Tools

This guide covers the MCP Framework's build-deploy workflow: generating tool descriptions, handling different data sizes, bundling multi-tool servers, and verifying deployments. The two most important concepts in this guide are **tool descriptions** and **managing large data**.
- LLMs use tool descriptions to decide *why* and *how* to call your function. The LLM needs to know what the function does and the type of each input and output parameter. You must provide this information.
- Large data requires external data sources and sinks. The LLM will call your function with the *location* of the data, rather than the *value*. The MCP Framework generates *wrapper functions* to read and write these locations.

Building an MCP tool from a MATLAB function is only one part of the MCP tool workflow. This guide assumes that you've already written and tested a MATLAB function. It works, it's correct, and you want to make it available to AI agents. When you're done here, your function will be live on MATLAB Production Server and responding to MCP requests. 

And your next step will be to [connect a client](./client-configuration.md).

## Contents

- [Build and deploy](#build-and-deploy)
- [How tool descriptions work](#how-tool-descriptions-work)
- [Functions with large data](#functions-with-large-data)
- [Multi-tool servers](#multi-tool-servers)
- [Deploying separately](#deploying-separately)
- [Verifying a deployment](#verifying-a-deployment)
- [Updating a deployed tool](#updating-a-deployed-tool)

---

## Build and Deploy

`build` turns your MATLAB function into an MCP server. Pass it:
- the name of your function
- an example function call
- the network address of your MATLAB Production Server instance

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

This:
1. Runs your example call to determine the input/output types
2. Combines argument types and source file comments into a tool description for the LLM
3. Packages everything into a deployable archive (`.ctf`)
4. Uploads the archive to MATLAB Production Server

The `example` argument tells the framework *how* to call your function. The framework watches that call and infers parameter types from what it observes.

Because all inputs here are small (a 3-element vector and a string), the framework passes them directly — no data marshaling needed. See [Functions with large data](#functions-with-large-data) for when the framework generates a wrapper automatically.

---

## How Tool Descriptions Work

The framework combines three sources to produce a complete tool description — what the function does, what it accepts, and what it returns:

1. **Function comments** — semantics (what each parameter means, what the function does)
2. **Example calls** — observed types and shapes of both inputs and outputs
3. **Argument blocks** — declared constraints, sizes, and per-argument documentation

Each source contributes different information. Together they give the LLM everything it needs to call your function correctly and interpret the results.

Your role in the process:
- Describe what your function does in the comment following the function line.
- Specify the type, size and shape of each parameter using example calls and argument blocks.

### Function comments

The comment block after your `function` line is always required. It becomes the tool's description — the text the LLM reads to decide whether and how to call the tool.

```MATLAB
function sigma = principalStress(stressState, component)
% Compute principal stresses using Mohr's circle.
%
%    sigma = principalStress(stressState, component) computes the principal
%        stress component ("min", "max", "maxShear") in MPa from the 2D
%        stressState [tension, compression, shear].
%
%  Example: 
%    sigma = principalStress([120 -50 80], "max") computes the maxiumum principal
%        stress component with 120 MPa tension, -50 MPa compression and 
%        80 MPa shear. 
```

Write comments for the LLM: be specific about what each parameter means, what values are valid, and what units to use. Examples in the comments help the LLM call the function correctly.

### Example calls

The `example` argument to `build` tells the framework how to call your function. The framework runs each example and observes the types and shapes of both inputs *and* outputs:

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));
```

The framework sees that `stressState` is a 3-element double vector, `component` is a string, and the output `sigma` is a scalar double. All three facts appear in the tool description.

When your function accepts different types at the same position, pass multiple examples so the framework captures each pattern. Consider a sensor conversion function:

```MATLAB
function celsius = convertSensor(reading, channel)
% Convert a sensor reading to degrees Celsius.
%
%    celsius = convertSensor(reading, channel) converts reading from
%        the named channel. reading is either raw ADC counts (uint16)
%        or calibrated voltages (double).
```

Build with two examples — one for each type of `reading`:

```MATLAB
ctf = prodserver.mcp.build("convertSensor", ...
    example={@() convertSensor(uint16(rawCounts), "temperature"), ...
             @() convertSensor(voltages, "temperature")});
```

The framework sees that `reading` is sometimes a `uint16` vector (raw ADC counts) and sometimes a `double` vector (calibrated voltages), and records both patterns in the tool description.

### Argument blocks

When your function declares argument blocks, the framework extracts type and size constraints directly. Each argument in the block requires an accompanying comment — this is how argument blocks add per-parameter documentation to the description:

```MATLAB
function count = countExceedances(measurements, threshold)
    arguments
        measurements (:,1) double  % Time series of sensor readings
        threshold (1,1) double     % Level above which a reading counts
    end
    arguments (Output)
        count (1,1) uint32         % Number of readings exceeding the threshold
    end
    count = uint32(sum(measurements > threshold));
end
```

The framework reads the argument declarations — a double column vector, a double scalar, and a `uint32` scalar — and includes each type and comment in the tool description.

For functions where argument blocks fully specify the types and sizes, no `example` is needed:

```MATLAB
ctf = prodserver.mcp.build("countExceedances", server="http://localhost:9910");
```

### How the sources combine

When both `example` and argument blocks are present, the framework merges information from both. Observed types fill gaps that argument blocks leave (struct field names, cell contents). Argument block constraints take precedence for size declarations — `(:,1)` is more general than observing a specific 5-element vector.

### Which approach to use

| Situation | Approach |
| :--- | :--- |
| Simple types, argument blocks declared | Argument blocks alone may suffice |
| Complex types (structs, cells, tables) | Use `example` — always |
| No argument blocks | Use `example` |
| Different types at the same position | Multiple examples |
| Want output types documented | Use `example` or output argument blocks |
| Argument blocks + want richer type detail | Combine both |

For full details on how the framework generates descriptions, see [Describing Functions](../concepts/describing-functions.md). For the `%#schema` annotation syntax, see the [Schema Format reference](../reference/schema-format.md).

---

## Functions with Large Data

When your function accepts or returns large arrays, passing them directly in the JSON request wastes tokens and can exceed message limits. The framework solves this with *data marshaling* — routing large values through file storage.

### Automatic wrapper generation

If you omit the `wrapper` argument (or set it to `"Auto"`), the framework examines parameter sizes and generates a wrapper function for any parameter that exceeds 64 elements. Auto requires argument blocks to determine parameter sizes. Functions without argument blocks are assumed to have small parameters and no wrapper is generated.

The wrapper:

- Replaces large input arrays with URL parameters (the LLM passes a `file:` URI instead of the data)
- Replaces large output arrays with URL parameters (the result is written to a file; the LLM gets the URI)

```MATLAB
% filterSignal has a large input array — the framework generates a wrapper automatically
ctf = prodserver.mcp.build("filterSignal", ...
    example=@() filterSignal(noisySignal, 60), ...
    server="http://localhost:9910");
```

The generated wrapper (`filterSignalMCP.m`) becomes the tool's entry point. Your original function is unchanged.

### Custom wrappers

For complex data flows (e.g., reading CSV with custom import options, writing multiple output files), write your own wrapper and pass its path:

```MATLAB
ctf = prodserver.mcp.build("earthquakeAnalysis", ...
    wrapper="earthquakeAnalysisMCP.m", ...
    server="http://localhost:9910");
```

See the [Periodic Noise](../../Examples/Periodic%20Noise/PeriodicNoise.md) example for automatic marshaling and the [Earthquake](../../Examples/Earthquake/Earthquake.md) example for a custom wrapper.




---

## Multi-Tool Servers

Bundle related functions into a single MCP server. The LLM sees all tools at one endpoint and can call any of them:

```MATLAB
[ctf, endpoint] = prodserver.mcp.build(["principalStress", "vonMises", "safetyFactor"], ...
    example={@() principalStress([120 -50 80], "max"), ...
           @() vonMises([120 -50 80]), ...
           @() safetyFactor([120 -50 80], 250)}, ...
    server="http://localhost:9910");
```

All three tools deploy to a single endpoint. The archive name defaults to the first function name; override with `archive`:

```MATLAB
ctf = prodserver.mcp.build(["principalStress", "vonMises", "safetyFactor"], ...
    example={...}, ...
    archive="stressAnalysis", ...
    server="http://localhost:9910");
```

The endpoint becomes `http://localhost:9910/stressAnalysis/mcp`.

See the [Multiple Tools example](../../Examples/MultiTool/MultipleTools.md) for a complete walkthrough.

---

## Deploying Separately

You don't have to build and deploy in one step. Omit `server` to produce just the archive:

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));
```

Then deploy later:

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

This is useful when you want to build once and deploy to multiple servers, or when build and deploy happen in different environments.

See the [`deploy` reference](../reference/deploy.md) for options including scheme, timeout, and retry.

---

## Verifying a Deployment

After deploying, confirm the tool is live with `ping`:

```MATLAB
prodserver.mcp.ping(endpoint)
```
```
ans =
    true
```

Call the tool directly to verify it returns the expected result:

```MATLAB
sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "max")
```
```
sigma =
  151.7262
```

List the tools available at the endpoint:

```MATLAB
tools = prodserver.mcp.list(endpoint, "Tool")
```

If `ping` returns `false`, the archive hasn't finished loading — MPS needs a few seconds after receiving a new archive. If `call` throws an error, check that your example inputs match what the function expects.

---

## Updating a Deployed Tool

To update a deployed tool, rebuild and redeploy. MPS replaces the archive atomically — clients see either the old version or the new version, never a partial state.

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

The endpoint URL doesn't change. Connected clients don't need reconfiguration.

---

## What's Next

| Goal | Read |
| :--- | :--- |
| Connect a client to your tool | [Client Configuration](./client-configuration.md) |
| Add reference data alongside tools | [MCP Resources](./resources.md) |
| Monitor tool usage | [Server Metrics](./server-metrics.md) |
| Let an AI agent build for you | [AI Agent Skills](./agent-skills.md) |
| Full `build` API details | [`build` reference](../reference/build.md) |

--- Copyright 2026 The MathWorks, Inc. ---
