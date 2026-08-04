function mustMatchSchema(value,var,td,tool,io)
% mustMatchSchema Error if value does not conform to the schema for tool's
% io variable named var. (IO is either "input" or "output").

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField

    if hasField(td,MCPConstants.DefinitionVariable) == false
        throwAsCaller(MException("prodserver:mcp:InvalidDefinition", ...
            "Tool definition structure lacks required field %s", ...
            MCPConstants.DefinitionVariable));
    end

    td = td.(MCPConstants.DefinitionVariable);

    % Extract the schema for this tool.
    if hasField(td,"tools")
        toolNames = cellfun(@(t)t.name,td.tools);
        t = strcmp(toolNames,tool);
        if nnz(t) ~= 1
            throwAsCaller(MException("prodserver:mcp:WrongNumberOfTools", ...
                "Expecting exactly 1 tool named '%s', but found %d", ...
                tool,nnz(t)));
        end
        description = td.tools{t};
    else
        throwAsCaller(MException("prodserver:mcp:NoSchemaForTool", ...
          "No schema found for tool %s.", tool));
    end

    % Locate the input or output
    schema = description.(io+"Schema");

    % Validate value against the schema
    prodserver.mcp.validation.validateArgumentsWithSchema(schema,var,...
        {value});

end