function definition = defineForMCP(tools,fcns,availableAI,definitions, ...
    folder)
% Create a single MCP tool definition structure for one or more MCP tools.
% Use metafunction (R2026a and later) or generative AI to create MCP tool
% definition from the text in each function's file. tools, fcns and
% definitions may be vectors, but they must always be the same size, unless
% definitions is empty. (tools and fcns must ALWAYS be the same size.)

% Copyright 2025, The MathWorks, Inc.

    validateattributes(tools,["string","char","cell"], {"nonempty","vector"}, '', ...
        'tools',1);
    validateattributes(fcns,["string","char","cell"], {"nonempty","vector"}, '', ...
        'fcns',2);
    prodserver.mcp.validation.mustBeSameSize(1,{tools,fcns});
    
    for n = 1:numel(tools)
        if isempty(definitions)
            if isMATLABReleaseOlderThan("R2026a")
                if isempty(availableAI)
                    error("prodserver:mcp:Indescriable", ...
"MCP tool definition required but unavailable. No MCP tool definition " + ...
"provided and no generative AI available to create one.");
                else
    
                    td = prodserver.mcp.genai.mcpDescription(tools(n),fcns(n), ...
                        availableAI(1),folder,timeout,retry);
                end
            else
                td = prodserver.mcp.internal.mcpDefinition(tools(n),fcns(n));
            end
        else
            % Assume each of these is a complete description of a single 
            % tool. Add the "tools" value to the definition we're building.
    
            if exist(definitions(n),"file") == 2
                td = jsondecode(fileread(definitions(n)));
            elseif isstring(definitions(n))
                td = jsondecode(definitions(n));
            end
        end
    
        % MCP tool JSON expects tools field to have an array value,
        % event if there is only one tool. The only way to ensure
        % that is to place the tool description in a cell array.
        % Which is a good idea anyway because the structures won't
        % be identical even at the highest level, so might not
        % concatenate.
        %
        % signatures is not an array -- it's a structure with fieldnames
        % equal to the names of the tools. So copy the signature data by
        % field name.
        if iscell(td.tools)
            definition.tools = td.tools;
        elseif isstruct(td.tools)
            definition.tools{n} = td.tools;
        end
        for f = string(fieldnames(td.signatures))'
            definition.signatures.(f) = td.signatures.(f);
        end
    end
    % Returned definition must be a MATLAB structure decoded from a 
    % JSON string.
end