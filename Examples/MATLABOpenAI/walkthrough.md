# LLMs with MATLAB

Build an MCP host in MATLAB using the [LLMs with MATLAB](https://www.mathworks.com/matlabcentral/fileexchange/163796-large-language-models-llms-with-matlab) add-on. This example connects MATLAB to OpenAI's language models and demonstrates tool use via the ReAct interaction paradigm.

## Prerequisites

- The [cleanSignal](../Periodic%20Noise/walkthrough.md) MCP tool deployed to MATLAB Production Server
- The [LLMs with MATLAB](https://www.mathworks.com/matlabcentral/fileexchange/163796-large-language-models-llms-with-matlab) add-on installed
- Network access to OpenAI servers (consumes usage tokens)
- `openloopVoltage.csv` in your working directory

## Setup

Deploy the `cleanSignal` tool if you have not already:
```MATLAB
[ctf, endpoint] = prodserver.mcp.build("cleanSignal", server="http://localhost:9910");
```

Copy `openloopVoltage.csv` from the Periodic Noise example into your working directory.

## The MCP Host

`taskOpenAI` is a simple MCP host that interacts with OpenAI language models to process a single prompt. It uses the ReAct paradigm, which encourages the LLM to examine its own responses to plan multi-step solutions.

## Run the Example

```MATLAB
% Obtain the tool definition by querying the MCP server.
mcpTools = prodserver.mcp.list("http://localhost:9910/cleanSignal/mcp", "Tool");

% Set the prompt
prompt = "Remove the 60Hz periodic noise from the signal in the file " + ...
    "openloopVoltage.csv in the current directory. " + ...
    "Name the output file openloopVoltage_clean.csv";

% Ask the AI agent to perform the task using the tools.
taskOutput = taskOpenAI(prompt, mcpTools);

% Display the filtered signal
result = extract(taskOutput, "openloopVoltage_" + wildcardPattern + ".csv");
data = readmatrix(result);
figure
plot(data);
title("Cleaned Signal (via OpenAI + MCP)");
```

## How It Works

1. `prodserver.mcp.list` queries the MCP server for tool definitions
2. `taskOpenAI` converts MCP tool definitions into OpenAI function-calling format
3. The LLM receives the prompt and available tools, decides to call `cleanSignal`
4. `evaluateToolCall` forwards the LLM's function call to the MCP server
5. The result is returned to the LLM, which reports success to the user

## References

Shunyu Yao, Jeffrey Zhao, Dian Yu, Nan Du, Izhak Shafran, Karthik Narasimhan, and Yuan Cao. "ReAct: Synergizing Reasoning and Acting in Language Models". ArXiv, 10 March 2023. https://doi.org/10.48550/arXiv.2210.03629.

--- Copyright 2025-2026 The MathWorks, Inc. ---
