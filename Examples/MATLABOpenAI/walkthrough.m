%% LLMs with MATLAB
% Build an MCP host in MATLAB using the LLMs with MATLAB add-on. This
% example connects to OpenAI and demonstrates tool use via the ReAct
% paradigm.
%
% Prerequisites:
%   - cleanSignal MCP tool deployed to localhost:9910
%   - LLMs with MATLAB add-on installed
%   - Network access to OpenAI (consumes usage tokens)
%   - openloopVoltage.csv in the current directory

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Obtain Tool Definitions from MCP Server
% Query the deployed cleanSignal server for its tool definitions.

mcpTools = prodserver.mcp.list(mpsServer + "/cleanSignal/mcp", "Tool");
mcpTools.name
mcpTools.description

%% Define the Prompt
% Ask the LLM to remove 60 Hz noise from the signal file.

prompt = "Remove the 60Hz periodic noise from the signal in the file " + ...
    "openloopVoltage.csv in the current directory. " + ...
    "Name the output file openloopVoltage_clean.csv";

%% Run the AI Agent
% |taskOpenAI| is a ReAct agent that plans and executes tool calls via
% OpenAI's function-calling API.

taskOutput = taskOpenAI(prompt, mcpTools);

%% Display the Result

result = extract(taskOutput, "openloopVoltage_" + wildcardPattern + ".csv");
data = readmatrix(result);
figure
plot(data);
title("Cleaned Signal (via OpenAI + MCP Tool)");
xlabel("Sample"); ylabel("Voltage");

%% How It Works
% 1. |prodserver.mcp.list| queries the MCP server for tool definitions
% 2. |taskOpenAI| converts MCP definitions to OpenAI function-calling format
% 3. The LLM receives the prompt and tools, decides to call |cleanSignal|
% 4. |evaluateToolCall| forwards the call to the MCP server
% 5. The result is returned to the LLM, which reports success


