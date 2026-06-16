function tools = mcpToOpenAI(mcp)
% mcpToOpenAI Convert MCP tool definitions to openAIFunction objects.

% Copyright 2025, The MathWorks, Inc.

    % Dictionary mapping name to structure. 
    names = string({mcp.name});
    values = mcp;
    tools.mcp = dictionary(names,values);

    % Array of openAIFunction objects.
    tools.openAI = arrayfun(@(t)openAIFcn(t),mcp);
end

function oAIF = openAIFcn(mcpDefinition)
%openAIFcn Create an openAIFunction object from an MCP tool definition.

    % All MCP tools have a name and a description.
    oAIF = openAIFunction(string(mcpDefinition.name), ...
        string(mcpDefinition.description));

    % If the MCP tool has inputs, add the corresponding parameter objects
    % to the openAIFunction object.
    if isfield(mcpDefinition,"inputSchema") && ...
            isfield(mcpDefinition.inputSchema,"properties")

        % A structure with one field for each input.
        in = mcpDefinition.inputSchema.properties;
        
        % Which parameters are required?
        required = string(mcpDefinition.inputSchema.required);
       
        % Add each input, specifying name, type and description.
        name = string(fieldnames(in));

        % names in required must come first, and be in the same order as
        % required arguments. Remove all required names from list of all
        % names, and then add the required names back at the beginning of
        % the list.
        if numel(name) > numel(required)
            name = setdiff(name,required);
            name = [required, name];
        else
            name = required;
        end

        % Parameters must be added in order: required first, then optional.
        for n = 1:numel(name)
            param = in.(name(n));

            % Defensive programming -- type and description may be empty.
            % THe LLM won't use the tool very well if they, but we allow
            % it.
            if isfield(param,"type")
                type = param.type;
            else
                type = "";
            end

            if isfield(param,"description")
                description = param.description;
            else
                description = "";
            end

            % Is the parameter required?
            req = ismember(name(n),required);

            oAIF = addParameter(oAIF,name(n), type=type, ...
                description=description, RequiredParameter=req);
        end
    end
end