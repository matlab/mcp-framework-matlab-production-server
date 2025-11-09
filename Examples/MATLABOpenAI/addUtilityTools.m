function tools = addUtilityTools(tools)
% addUtilityTools Add MATLAB-based function handle tools to the tool
% registry. Create both openAIFunction objects and the MCP-format
% structures required for taskOpenAI and evaluateToolCall.

% Copyright 2025, The MathWorks, Inc.

    %
    % Find current directory
    %

    name = "currentFolder";
    description = "Find the current directory.";
    currentFolder = openAIFunction(name, description);
    tools.openAI = [tools.openAI, currentFolder];
    outputs.cwd.type = "string";
    outputs.cwd.description = "Current working directory.";
    tools.mcp(name) = mcpTool(name,description,[],outputs,@pwd);
end

function mcp = mcpTool(name, description, inputs, outputs, fcn)
% Create MCP-format tool structure.
    mcp.name = name;
    mcp.description = description;
    mcp.inputSchema = mcpSchema(inputs);
    mcp.outputSchema = mcpSchema(outputs);
    mcp.server.type = 'function_handle';
    mcp.server.function = fcn;
end

function schema = mcpSchema(parameters)
% Create MCP-format schema describing function parameters.

    schema.type = 'object';
    if isempty(parameters)
        schema.properties = struct.empty;
        schema.required = cell.empty;
    else
        schema.required = fieldnames(parameters);
        schema.properties = parameters;
    end
end