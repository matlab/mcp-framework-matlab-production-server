function observation = evaluateToolCall(toolCall,tools)
% evaluateToolCall Execute a tool as instructed by an AI agent.

% Copyright 2025, The MathWorks, Inc.

    % Validate tool name
    toolName = toolCall.function.name;
    assert(isKey(tools.mcp,toolName),"Invalid tool name ''%s''.",toolName)
    
    % Validate JSON syntax
    try
        args = jsondecode(toolCall.function.arguments);
    catch
        error("Model returned invalid JSON syntax for arguments of tool ''%s''.",toolName);
    end
    
    % Validate tool parameters
    tool = tools.mcp(toolName);
    requiredArgs = string(tool.inputSchema.required);
    assert(all(isfield(args,requiredArgs)),"Invalid tool parameters: %s",strjoin(fieldnames(args),","))
    
    % Remove non-required parameters. Clearly this represents an area for
    % enhancement.
    extraArgs = setdiff(string(fieldnames(args)),requiredArgs);
    if ~isempty(extraArgs)
        warning("Ignoring extra tool parameters: %s",strjoin(extraArgs,","));
    end
    
    % Execute tool -- currently supporting HTTP-based MCP tools and
    % MATLAB-based function handle tools. Others can be added here -- stdio
    % is an obvious candidate.
    argValues = arrayfun(@(fieldName) args.(fieldName),requiredArgs,UniformOutput=false);
    if strcmpi(tool.server.type,"http")
        [status,msg] = prodserver.mcp.feval(tool.server.url,toolName,argValues{:});
        if status == false
            observation = msg;
        else
            observation = "Success";
        end
    elseif strcmpi(tool.server.type,'function_handle')
        try
            nOut = nargout(tool.server.function);
            if nOut > 0
                observation = feval(tool.server.function,argValues{:});
            else
                feval(tool.server.function,argValues{:});
                observation = "Success";
            end
        catch me
            observation = me.message;
        end
    else
        error("Unsupported MCP server type: %s", tool.server.type);
    end
end