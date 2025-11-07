function definition = mcpDefinition(tool,fcn)
%mcpDefinition Generate a definition for tool from the code in fcn.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.parameterDescription


    if exist(fcn,"file") == false
        error("prodserver:mcp:ToolFcnNotFound", "MCP function %s " + ...
            "not found.", fcn);
    end

    mf = metafunction(fcn);

    if isempty(mf)
        error("prodserver:mcp:CannotParseToolFcn", "Cannot parse MCP " + ...
            "function file %s. Verify that the file contains at least one " + ...
            "MATLAB function.", fcn);
    end

    %
    % MCP Tool Description
    % 
    definition.tools.name = tool;
    % Make description into a single line.
    d = strtrim(mf.Description);
    if isempty(mf.DetailedDescription)
        dd = { d };
    else
        dd = strtrim(split(mf.DetailedDescription,newline));
        dd = [ {d}; dd ];
    end

    definition.tools.description = strjoin(dd," ");

    % Tool description must be a non-empty string.
    txt = definition.tools.description;
    if isempty(txt) || (isstring(txt) && strlength(text) == 0) 
        error("prodserver:mcp:EmptyToolDescription", "Empty tool " + ...
            "description for %s. Add descriptive comment to %s following " + ...
            "the function line.", fcn, mf.FullPath);
    end

    % Description of inputs
    definition.tools.inputSchema.type = "object";
    [properties,required] = argumentDeclaration(mf.Signature.Inputs);
    definition.tools.inputSchema.properties = properties;
    definition.tools.inputSchema.required = required;

    % Description of outputs
    [properties,required] = argumentDeclaration(mf.Signature.Outputs);
    definition.tools.outputSchema.properties = properties;
    definition.tools.outputSchema.required = required;

    % Heuristic searching about for comments that describe each input and
    % output argument.

    [in,out] = parameterDescription(mf);
    if ~isempty(in)
        definition = addDescriptionToSchema(definition,"inputSchema",in);
    end
    if ~isempty(out)
        definition = addDescriptionToSchema(definition,"outputSchema",out);
    end

    % 
    % MPS mapping of tool name to callable MATLAB function
    %
    definition.signatures.(tool).function = mf.Name;

    if hasField(definition.tools,"inputSchema")
        [name,type] = mpsArguments(definition.tools.inputSchema.properties);
        definition.signatures.(tool).input.name = name;
        definition.signatures.(tool).input.type = type;
    end

    if hasField(definition.tools,"outputSchema")
        [name,type] = mpsArguments(definition.tools.outputSchema.properties);
        definition.signatures.(tool).output.name = name;
        definition.signatures.(tool).output.type = type;
    end
end

function definition = addDescriptionToSchema(definition,schema,ad)
% Copy the description text into the "description" field of each argument
% in the schema. ad is a dictionary: name -> description. If the
% description has multiple lines, join the lines together into a single
% line.
for arg = keys(ad)'
    definition.tools.(schema).properties.(arg).description = ...
        strjoin(ad(arg).description," ");
end
end

function [name,type] = mpsArguments(schema)
    name = string(fieldnames(schema));
    type = arrayfun(@(i)string(schema.(i).type), name);
end

function [properties,required] = argumentDeclaration(args)
% Extract argument names and types, but not descriptions from an argument
% block. Return an MCP properties structure and an array of the names of
% the required arguments.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField

    names = cell(1,numel(args));
    decl = cell(size(names));
    required = false(size(names));
    for i = 1:numel(args)
        names{i} = args(i).Identifier.Name;
        required(i) = args(i).Required;
        t = MCPConstants.DefaultArgType;
        if hasField(args(i),"Validation.Class")
            if ~isempty(args(i).Validation.Class)
                t = args(i).Validation.Class.Name;
            end
        end
        d.type = t;
        % No time-frame for mf.Signature.Inputs(i).Description, so
        % placeholder for now and fix-up later.
        d.description = t;

        decl{i} = d;
    end
    args = [ names; decl ];
    properties = struct(args{:});
    required = names(required);
end


