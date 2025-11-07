function mustBeToolDefinition(x)
% mustBeToolDefinition Error if X is not an MCP tool definition.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.hasField

    % Empty OK.
    if isempty(x)
        return;
    end

    validateattributes(x,["function_handle","struct","cell","string"],"nonempty");
    
    % Explode homogeneous structure array into cell array of scalar
    % structures. Simplifies processing of cell array of heterogeneous
    % structures.
    if isstruct(x)
        if hasField(x,"tools") == false
            error("prodserver:mcp:ToolDefinitionMissingTools",...
                "MCP tool definition structure missing required field " + ...
                "named 'tools'.");
        end
        x = num2cell(x.tools);
    end

    if isstring(x)
        mustBeFile(x);
    elseif iscell(x)
        for n = 1:numel(x)
            if isstruct(x{n}) == false
                error("prodserver:mcp:ToolDefinitionNotStruct", ...
                    "Expecting definition of MCP tool %d to be a " + ...
                    "structure but found %s instead.",n,class(x{n}));
            end
            fields = ["name", "description"];
            if hasField(x{n},"inputSchema")
                fields = [fields, "inputSchema.properties", ...
                    "inputSchema.type", "inputSchema.required"];
            end
            if hasField(x{n},"outputSchema")
                fields = [fields, "outputSchema.properties", ...
                    "outputSchema.type", "outputSchema.required"];
            end
            for f = fields
                if hasField(x{n},f) == false
                    if hasField(x{n},"name")
                        id = x{n}.name;
                    else
                        id = string(n);
                    end
                    error("prodserver:mcp:MissingToolDefinitionField", ...
                        "Definition for MCP tool %s missing field %s.", id, f);
                end
            end
        end
        
	elseif isa(x,"function_handle")
        % Handle of a function that generates a MATLAB function MCP
        % definition. The function must exist.

        w = which(func2str(x));
        if isempty(w)
            error("prodserver:mcp:ToolDefinitionGeneratorNotFound", ...
                "Definition generator function %s not found.", ...
                func2str(x));
        end
    end
end
