function definition = mcpDefinition(tool,fcn,typemap)
%mcpDefinition Generate a definition for tool from the code in fcn.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.parameterDescription

    % Optional mapping of MATLAB types to JSONRPC types.
    if nargin < 3
        typemap = [];
    end

    if exist(fcn,"file") == false
        error("prodserver:mcp:ToolFcnNotFound", "MCP function %s " + ...
            "not found.", fcn);
    end

    mf = prodserver.mcp.internal.metafunction(fcn);

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

    % MPS mapping of tool name to callable MATLAB function
    definition.signatures.(tool).function = mf.Name;

    % Heuristic searching about for comments that describe each input and
    % output argument.
    [in,out] = parameterDescription(mf);

    % Define inputs
    definition = defineParameters(definition,tool,"input",in, ...
        mf.Signature.Inputs,typemap);
 
    % Define outputs
    definition = defineParameters(definition,tool,"output",out, ...
        mf.Signature.Outputs,typemap);
end

function definition = defineParameters(definition,tool,io,descriptions, ...
    signature,typemap)
% Define a set of parameters, either input or output. Use introspection to
% collect parameter names and types. metafunction doesn't support parameter
% descriptions yet so they are extracted using a heuristic process.
%
%  definition: Structure capturing all knowledge about the tool. This
%      function adds information about parameters.
%  tool: Name of the tool.
%  io: "input" or "output" -- the group of parameters we're processing.
%  descriptions: Parameter descriptions extracted from function text.
%  signature: metafunction data on the group of parameters.
%  typemap: Maps "extra" MATLAB types to JSONRPC types. A structure.

    % Set schema name based on parameter group -- input or output.
    if strcmp(io,"input")
        schema = "inputSchema";
    elseif strcmp(io,"output")
        schema = "outputSchema";
    end

    % Collect input argument information from metafunction data.
    [parameters,required] = argumentDeclaration(signature);
    
    % Update parameter structure with descriptions.
    if ~isempty(descriptions)
        parameters = addDescription(parameters,descriptions);
    end
    
    % Populate MATLAB signature structure with MATLAB native types.
    if ~isempty(parameters)
        [name,type] = mpsArguments(parameters);
        definition.signatures.(tool).(io).name = name;
        definition.signatures.(tool).(io).type = type;
    end
    
    % Convert MATLAB types to compatible JSON types
    parameters = mcpArgumentTypes(parameters,typemap);
    
    % Description of parameters
    definition.tools.(schema).type = "object";
    if isempty(fieldnames(parameters)) == false
        definition.tools.(schema).properties = parameters;
        definition.tools.(schema).required = required;
    end
    definition.tools.(schema).additionalProperties = false;
end


function parameters = addDescription(parameters,ad)
% Copy the description text into the "description" field of each parameter.
% ad is a dictionary: name -> description. If the description has multiple 
% lines, join the lines together into a single line.
    for arg = keys(ad)'
        parameters.(arg).description = strjoin(ad(arg).description," ");
    end
end

function t = parameterTypeName(type)
    import prodserver.mcp.MCPConstants

    % type will be simple string for scalar parameters and a
    % structure for array parameters. Return the type name of the
    % elements of the array or the scalar type name.
    if strcmpi(type.type,MCPConstants.Array)
        t = type.items.type;
    else
        t = type.type;
    end
end

function [name,type] = mpsArguments(schema)
    name = string(fieldnames(schema));
    type = arrayfun(@(i)string(parameterTypeName(schema.(i))), name);
end

function parameters = mcpArgumentTypes(parameters,typemap)
    import prodserver.mcp.MCPConstants

    name = string(fieldnames(parameters));
    for n = 1:numel(name)
        t = jsonParameterType(parameterTypeName(parameters.(name(n))), ...
            typemap);
        if isempty(t)
            error("prodserver:mcp:IncompatibleArgumentType", ...
                "Parameter '%s' has unsupported type '%s'. Valid types " + ...
                "include numeric types, strings, cell arrays and " + ...
                "structures.", name(n), parameters.(name(n)).type);
        end

        % Array and scalar have different representation.
        if strcmpi(parameters.(name(n)).type, MCPConstants.Array)
            % Array
            parameters.(name(n)).items.type = t;
        else
            % Scalar
            parameters.(name(n)).type = t;
        end

    end
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

        % Array or scalar? Everything is an array (because MATLAB) unless 
        % explicitly declared otherwise. Create a structure that will 
        % result in one of two JSON encodings.
        %
        % For array parameters:
        %   {
        %       "type": "array",
        %       "items": { "type": "<MATLAB type name>" }
        %   }
        % If the parameter has a size validation like (1,3,2), the
        % structure will include the "maxItems" field (with value 6 in this
        % case.)
        %
        % For scalar parameters (where the size is explicitly (1,1)):
        %   {
        %       "type": "<MATLAB type name>" 
        %   }
        %
        % Some MCP hosts appear to validate against the schema. Others do
        % not. YMMV. Forthe ones that do, the schema must be correct.

        d.type = "array";
        d.items.type = t;
        if hasField(args(i),"Validation.Size") && ...
            ~isempty(args(i).Validation.Size)
            % If any dimension is unrestricted, there is no size limit.
            % Otherwise, maxItems is the product of the dimensions.

            dims = args(i).Validation.Size;
            maxItems = 1;
            for dI = 1:numel(dims)
                if isa(dims(dI),'matlab.metadata.UnrestrictedDimension')
                    sz = Inf;
                elseif isa(dims(dI),'matlab.metadata.FixedDimension')
                    sz = dims(dI).Length;
                end
                maxItems = maxItems * sz;
            end
            if ~isinf(maxItems) && maxItems > 1
                d.maxItems = maxItems;
            end

            % Check for scalar -- and undo all work above, if so. Create
            % the much simpler scalar declaration.
            if maxItems == 1
                d = [];
                d.type = t;
            end
          
        end

        % No time-frame for mf.Signature.Inputs(i).Description, so
        % placeholder for now and fix-up later.
        d.description = t;

        decl{i} = d;
        d = [];   % To allow it to be string or structure again.
    end

    % Structure with one field per argument. name -> (type, description)
    % Except description is empty right now -- to be filled in later.
    args = [ names; decl ];
    properties = struct(args{:});
    required = names(required);
end

function jsonType = jsonParameterType(matlabType,typemap)
% Map MATLAB types to JSON RPC types. The only valid types for JSON are:
% array, boolean, integer, null, number, object, string. In this list,
% "object" means struct.
% 
% Return a "" string if there is no compatible JSON type.

    arguments
        matlabType string
        typemap struct
    end

    intType = textBoundary("start") + ("int" | "uint") + ...
        ("8" | "16" | "32" | "64" | "128") + textBoundary("end");
    
    jsonType = strings(1,numel(matlabType));

    for n = 1:numel(matlabType)

        % Special case types first -- user specified these conversions, so
        % honor them.
        if ismember(matlabType(n),fieldnames(typemap))
            jsonType(n) = typemap.(matlabType(n));
        % Character types become string
        elseif strcmp(matlabType(n),"char") || strcmp(matlabType(n),"string")
            jsonType(n) = "string";
    
        % All integer types become "integer"
        elseif matches(matlabType(n),intType)
            jsonType(n) = "integer";
    
        % Floating point types are "number"
        elseif strcmp(matlabType(n),"double") || strcmp(matlabType(n),"float")
            jsonType(n) = "number";
    
        % Data with named fields is an "object"
        elseif strcmp(matlabType(n),"struct")
            jsonType(n) = "object";
    
        % logical -> boolean
        elseif strcmp(matlabType(n),"logical")
            jsonType(n) = "boolean";
    
        % cell arrays are JSON arrays
        elseif strcmp(matlabType(n),"cell")
            jsonType(n) = "array";
    
        % No compatible JSON type for this MATLAB type. 
        else
            jsonType(n) = "";
        end
    end
end