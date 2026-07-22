function definition = mcpDefinition(tool,fcn,opts)
%mcpDefinition Generate a definition for tool from the code in fcn.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments(Input)
        tool (1,1) string  % Name of the tool on the MCP server.
        fcn (1,1) string   % Function the tool calls. Must be on the MATLAB path.
        opts.encoding (1,1) prodserver.mcp.WireEncoding = "Invertible";
        opts.typemap struct {mustBeScalarOrEmpty} = []
        opts.defs struct {mustBeScalarOrEmpty} = []
        opts.stage (1,1) prodserver.mcp.BuildStage = "Definition"
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.parameterDescription    

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

    % Tool description must be a non-empty string. isstring() test because
    % [ {d}; string.empty ] creates a string -- so if
    % mf.DetailedDescription ever comes back as an empty string, we'll
    % still error correctly.
    if (iscell(dd) && isempty(dd{1})) || (isstring(dd) && strlength(dd) == 0)
        error("prodserver:mcp:EmptyToolDescription", "Empty tool " + ...
            "description for %s. Add descriptive comment to %s following " + ...
            "the function line.", fcn, mf.FullPath);
    end

    % Add a statement requiring the LLM to read the wire-encoding resource
    % before making any calls to the tool. Don't add it twice. But add it
    % after the check for empty description above, or we'll never detect
    % undescribed functions.
    if opts.encoding == prodserver.mcp.WireEncoding.Invertible && ...
            any(contains(dd,MCPConstants.WireEncodingResourceURI)) == false
        dd = [ dd; {char(prodserver.mcp.MCPConstants.WireEncodingRequiredMsg)} ];
    end

    dd = strjoin(dd," ");
    definition.tools.description = dd;

    % MPS mapping of tool name to callable MATLAB function
    definition.signatures.(tool).function = mf.Name;

    % Heuristic searching about for comments that describe each input and
    % output argument.
    [in,out,inHasNVP] = parameterDescription(mf);

    % TODO: Don't do this.
    % If the function has optional name value pair arguments, add a comment
    % to the tool description describing how an AI agent should form the
    % argument list.
    % if inHasNVP
    %     % Don't duplicate NVP calling convention comment.
    %     if contains(definition.tools.description, ...
    %             MCPConstants.OptionalGroupMsg) == false
    %         definition.tools.description = [ ...
    %             definition.tools.description; ...
    %             MCPConstants.OptionalGroupMsg ...
    %         ];
    %     end
    % end

    % Enumerate externalized inputs and outputs
    externalIn = string.empty; 
    externalOut = string.empty;
    if ~isempty(opts.defs)
        if hasField(opts.defs,"inputSchema")
            externalIn = fieldnames(opts.defs.inputSchema);
        end
        if hasField(opts.defs,"outputSchema")
            externalOut = fieldnames(opts.defs.outputSchema);
        end
    end

    % Define inputs
    definition = defineParameters(definition,tool,"input",in, ...
        mf.Signature.Inputs,opts.typemap,opts.stage,opts.encoding,...
        externalIn);
 
    % Define outputs
    definition = defineParameters(definition,tool,"output",out, ...
        mf.Signature.Outputs,opts.typemap,opts.stage,opts.encoding, ...
        externalOut);

    % Add $defs to the definition. Since the definition is a structure,
    % we can't use $defs as a field name, as it is not a valid MATLAB
    % variable name. (This will require fix-up when description is returned
    % as JSON from server.)
    if ~isempty(opts.defs)
        definition.tools.(MCPConstants.DefsField) = opts.defs;
        if hasField(opts.defs,"outputSchema")
            external = fieldnames(opts.defs.outputSchema);
            for n = 1:numel(external)
                definition.tools.inputSchema.properties.(external{n}).writeOnly = true;
                definition.tools.inputSchema.properties.(external{n}).examples = ...
                    MCPConstants.ByReferenceOutExample;
            end
        end
    end
end

function definition = defineParameters(definition,tool,io,descriptions, ...
    signature,typemap,stage,encoding,external)
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
%  stage: Stage of the build process.

    import prodserver.mcp.internal.ParameterKind
    
    % Set schema name based on parameter group -- input or output.
    if strcmp(io,"input")
        schemaName = "inputSchema";
    elseif strcmp(io,"output")
        schemaName = "outputSchema";
    end

    % User-specified schema data may be present in the description. Extract
    % it from the comments and insert it into the descriptions structure.
    % Also inject a comment explaining how to manage the wire encoding.
    if ~isempty(descriptions)
        descriptions = argumentSchema(descriptions);
        if encoding == prodserver.mcp.WireEncoding.Invertible
            descriptions = explainWireEncoding(descriptions,io,external);
        end
    end

    % Collect argument information from metafunction data.
    [parameters,required,kind,order,group,validation,default] = ...
        argumentDeclaration(signature,descriptions,encoding);
    
    % Update parameter structure with descriptions.
    if ~isempty(descriptions)
        parameters = setDescription(parameters,descriptions,stage);
    end
    
    % Populate MATLAB signature structure with MATLAB native types.
    if ~isempty(parameters)
        [name,type] = mpsArguments(parameters);
        definition.signatures.(tool).(io).name = name;
        definition.signatures.(tool).(io).type = type;
        definition.signatures.(tool).(io).kind = kind;
        definition.signatures.(tool).(io).order = order;
        definition.signatures.(tool).(io).group = group;
        definition.signatures.(tool).(io).validation = validation;
        definition.signatures.(tool).(io).default = default;
    end
    
    % Convert MATLAB types to compatible JSON types
    parameters = mcpArgumentTypes(parameters,typemap);
    
    % Description of parameters
    definition.tools.(schemaName).type = "object";
    if isempty(fieldnames(parameters)) == false
        definition.tools.(schemaName).properties = parameters;
        definition.tools.(schemaName).required = required;
        [minArgs, maxArgs] = ParameterKind.NargRange(kind);
        definition.tools.(schemaName).minProperties = minArgs;
        definition.tools.(schemaName).maxProperties = maxArgs;
    end
    % Ideally we'd add this, but some LLMs (Gemini!) choke on the
    % "additionalProperties" field.
    %definition.tools.(schemaName).additionalProperties = false;
end


function parameters = setDescription(parameters,ad,stage)
% Copy the description text into the "description" field of each parameter.
% ad is a dictionary: name -> description. Maintain line breaks of
% description. If the stage is "Definition", remove build-time pragmas.
    import prodserver.mcp.internal.Constants
    
    for arg = keys(ad)'
        d = ad(arg).description;
        if stage == prodserver.mcp.BuildStage.Definition
            keep = true(size(d));
            for n = 1:numel(d)
                % Don't keep %#schema lines in the published description.
                if startsWith(d(n),Constants.Schema)
                    keep(n) = false;
                end
            end
            d = d(keep);
        end
        % MCP protocol requires single-string descriptions -- can't be an
        % array. Line breaks are OK.
        parameters.(arg).description = strjoin(d,newline);
    end
end

function t = parameterTypeName(type)
    import prodserver.mcp.MCPConstants

    % The location of the actual type of the parameter depends on the wire
    % encoding. If we're using the invertible encoding, the type is in the
    % properties sub-structure of the wrapper. Surface it. Use the
    % annotation field to determine if we're using the invertible encoding.
    % The contains test is looking for text in the
    % wireEncodingArgTemplate.json. So if you change that, change this.
    if isfield(type,"annotation") && contains(type.annotation,"Invertible wire encoding")
        type = type.properties.data;
    end

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
% Final adjustment to create MCP-compatible schema. 

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.SchemaOrigin

    name = string(fieldnames(parameters));
    for n = 1:numel(name)
        % Find the type name for this parameter.
        t = parameterTypeName(parameters.(name(n)));

        switch parameters.(name(n)).schema.origin
            case SchemaOrigin.Introspection
                % Expect MATLAB type
                t = jsonParameterType(t,typemap);
            case SchemaOrigin.Hybrid
                % Allow MATLAB or JSON type
                if prodserver.mcp.validation.isJsonSchemaType(t) == false
                    t = jsonParameterType(t,typemap);
                end
            case SchemaOrigin.Client
                % Require JSON type.
                prodserver.mcp.validation.mustBeJsonSchemaType(t);
        end

        % Remove the schema field because it is not part of the JSON
        % schema. Take the schema out of the schema. :-)
        parameters.(name(n)) = rmfield(parameters.(name(n)),"schema");

        if isempty(t) || strlength(t) == 0
            if strcmp(parameters.(name(n)).type,"array")
                badType = parameters.(name(n)).items.type;
            else
                badType = parameters.(name(n)).type;
            end
            error("prodserver:mcp:IncompatibleArgumentType", ...
                "Parameter '%s' has unsupported MATLAB type '%s'. Valid " + ...
                "types include numeric types, strings, cell arrays and " + ...
                "structures.", name(n), badType);
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

function parameters = explainWireEncoding(parameters,io,external)
% Add the wire encoding reference to the description of each parameter.
    import prodserver.mcp.MCPConstants

    % For every parameter...
    param = keys(parameters)';

    if strcmpi(io,"input")
        wireEncodingMsg = MCPConstants.WireEncodingInputMsg;
    else
        wireEncodingMsg = MCPConstants.WireEncodingOutputMsg;
    end
    
    for p = param
        % Don't add encoding comment to externalized parameters.
        if nnz(ismember(p,external)) == 0
            % And don't add it twice.
            alreadyExplained = contains(parameters(p).description,...
                MCPConstants.WireEncodingResourceURI);

            if nnz(alreadyExplained) == 0
                parameters(p).description = [ parameters(p).description; ...
                    wireEncodingMsg ];
            end
        end
    end
end

function parameters = argumentSchema(parameters)
% Extract user-specified schema from comments in the description. 
%
% Allow the following syntax:
%
%   %#schema { "maxItems": 12 }
%   %#schema =x.json
%   %#schema +{ "x-call-by": "value" }
%
% In the first,the JSON schema appears literally. In the second, the JSON
% schema is contained in a file. In the third, the schema is added to
% to schema automatically derived from the MATLAB function. The parser 
% will use the "{" character to distinguish these cases.

    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.SchemaInjection
    import prodserver.mcp.internal.SchemaOrigin

    function [schema,inject,line] = findSchema(comment,p)
    % Search the comment lines for p to find a line that specifies the
    % schema for p. May or may not exist. 
        schema = []; line = 0;
        inject = SchemaInjection.Unknown;
        for n = 1:numel(comment)
            if startsWith(comment(n),Constants.Schema)
                % Found on line n
                line = n;

                % Found schema line -- replace or add properties?
                inject = SchemaInjection.Add;
                
                % If the schema source (literal or file) is preceded by an
                % "=", the user wants to COMPLETELY REPLACE (skip) the
                % generated schema. A "+", on the other hand, adds the
                % properties to the generated schema, overwriting any
                % autogenerated properties of the same name.
                if startsWith(comment(n),Constants.Schema + ...
                        whitespacePattern + SchemaInjection.ReplaceToken())
                    inject = SchemaInjection.Replace;
                end

                % Now, is it literal or file-based?
                if contains(comment(n), "{")
                    % Literal schema following the keyword.
                    schema = extractBetween(comment(n), "{", ...
                        textBoundary("end"), Boundaries="inclusive");
                    return;
                else
                    % File path follows the keyword and optional schema
                    % injection action token. File must exist.
                    file = strtrim(extractAfter(comment(n), ...
                        Constants.Schema + optionalPattern(...
                        whitespacePattern + characterListPattern(...
                        SchemaInjection.AddToken() + ...
                        SchemaInjection.ReplaceToken))));

                    if exist(file,"file") == 2
                        % Read all the data
                        schema = readlines(file);
                        % Trim leading and trailing whitespace.
                        schema = strtrim(schema);
                        % Join lines into a single string.
                        schema = strjoin(schema," ");
                    else
                        error("prodserver:mcp:SchemaFileNotFound", ...
                            "Unable to locate schema file %s for parameter %s.", ...
                            file,p)
                    end
                end
            end
        end
    end

    
    % For every parameter...
    param = keys(parameters)';

    % Using try-catch as flow of control only to provide a more
    % intelligible error message if the schema is invalid JSON.
    try
        for p = param
            [json,inject,line] = findSchema(parameters(p).description,p);
            
            if ~isempty(json)
                % Require that the schema data be valid JSON
                schema = jsondecode(json);
                % Add the schema to the parameter description.
                parameters(p).schema.line = line;
                parameters(p).schema.schema = schema;
                parameters(p).schema.inject = inject;

                % Knowing the origin of the schema helps with management of
                % type names. Client schemas must contain only JSON schema 
                % types.
                if inject == SchemaInjection.Add
                    parameters(p).schema.origin = SchemaOrigin.Hybrid;
                elseif inject == SchemaInjection.Replace
                    parameters(p).schema.origin = SchemaOrigin.Client;
                else
                    error("prodserver:mcp:InvalidSchemaInjection", ...
                        "Invalid schema injection type: %s", ...
                        string(inject));
                end  
            else
                parameters(p).schema.origin = SchemaOrigin.Introspection;
            end
        end
    catch me
        if startsWith(me.identifier,"MATLAB:json")
            error("prodserver:mcp:InvalidParameterSchema", ...
                "Invalid schema for parameter '%s': %s", ...
                p,me.message);
        else
            rethrow(me);
        end
    end

end

function [properties,required,kind,order,group,validation,default] = ...
    argumentDeclaration(args,parameters,encoding)
% Extract argument names and types, but not descriptions from an argument
% block. Return an MCP properties structure and an array of the names of
% the required arguments.
%
% All the returned types must be jsonencode-compatible, as they form part
% of the signature, which travels over the wire via JSONRPC. So no
% dictionaries, tempting as they may be.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.internal.SchemaInjection
    import prodserver.mcp.internal.SchemaOrigin
    import prodserver.mcp.jsonrpc.SchemaCallBy


    names = cell(1,numel(args));
    decl = cell(size(names));
    required = false(size(names));
    kind = repmat(ParameterKind.Unknown,size(names));
    % Should be dictionaries, but must be struct due to JSON constraints.
    group = [];
    default = [];
    validation = cell(size(names));

    % If we're using the precise, invertible encoding, wrap the user's
    % declaration in the encoding wrapper.
    wrapper = struct.empty;
    if encoding == prodserver.mcp.WireEncoding.Invertible
        % Fetch the wrapper text, a JSON object. Storing it as JSON
        % improves readability and maintainability.
        wrapper = fileread(fullfile(prodserver.mcp.internal.packageFolder(),...
            "+prodserver","+mcp","+jsonrpc","wireEncodingArgTemplate.json"));
        % Turn the wrapper text into a structure. Plain JSON, decodes
        % without ambiguity.
        wrapper = jsondecode(wrapper);
    end

    % Determine the properties of each argument, either by introspection 
    % or from a user-supplied schema.
    for i = 1:numel(args)

        % Parameter name
        names{i} = args(i).Identifier.Name;

        % Is the parameter required or optional? Name value pairs are
        % always optional. Positional arguments are optional if they are
        % assigned a default value in the argument block. Track positional
        % vs. name value precisely.
        required(i) = args(i).Required;
        kind(i) = ParameterKind.FromMetaData(required(i),args(i).Identifier);

        % The default type for all arguments, until we're told differently
        % by the argument block validation or the schema.
        t = MCPConstants.DefaultArgType;
        if hasField(args(i),"Validation.Class")
            if ~isempty(args(i).Validation.Class)
                t = args(i).Validation.Class.Name;
            end
        end

        % Argument block validation typically specifies one or more of size
        % (shape), data type and value constraints (mustBePositive, for
        % example).
        if hasField(parameters(names{i}),"validation") && ...
                strlength(parameters(names{i}).validation) > 0
            [sz,t,f,v] = argumentInfo(parameters(names{i}).validation);
            if isempty(t) 
                t = MCPConstants.DefaultArgType;
            end
            validation{i} = struct("size",sz,"type",t,"fcn",f);
            default.(names{i}) = v;
        else
            default.(names{i}) = "";
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
        % not. YMMV. For the ones that do, the schema must be correct.

        d.type = "array";
        d.items.type = t;

        % Validation may indicate the size of one or more dimensions. If
        % all dimensions have a finite size, we can compute the maximum
        % number of elements, which JSONSchema uses.
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

        % Record variable group membership. Optional arguments have a
        % "group"; the name of the "structure" of which they are fields.
        % Must be string, not char, as subsequent code expects the result
        % of concatenation to retain the number of arguments, even if the
        % group is empty.
        group.(args(i).Identifier.Name) = string(args(i).Identifier.GroupName);

        % Inject user-specified schema properties. This may modify or
        % undo some or all of the work done above, by design.
        d.schema.line = 0;
        if parameters(names{i}).schema.origin ~= SchemaOrigin.Introspection
            schema = parameters(names{i}).schema;
            d.schema.line = schema.line;
            inject = schema.inject;
            schema = schema.schema;

            % The user-specified schema may either add to or replace the
            % autogenerated schema.
            if inject == SchemaInjection.Replace
                d = [];
            end

            propertyNames = string(fieldnames(schema))';
            for p = propertyNames
                [pth,val] = nestedFieldValues(schema,p);
                for f = 1:numel(pth)
                    fPth = pth{f};
                    d = setfield(d,fPth{:},val{f}); 
                end
            end
        end
        % Whence did the schema originate?
        d.schema.origin = parameters(names{i}).schema.origin;

        % No time-frame for mf.Signature.Inputs(i).Description, so
        % placeholder for now and fix-up later.
        d.description = t;

        % If we're using the invertible wire encoding, wrap the argument in
        % the invertible envelope.
        if ~isempty(wrapper) 
            % Get a clean copy of the wrapper object.
            thisWrapper = wrapper;

            % Move the schema field to the top level of the structure,
            % whence it will be appropriately removed later.
            thisWrapper.schema = d.schema; d = rmfield(d,"schema");

            % Move the description field to the top level of the structure,
            % where the LLM will see it.
            thisWrapper.description = d.description; d = rmfield(d,"description");

            % Move the call by field, if there is one, to the top level of
            % the structure, so that it properly influences
            % externalization.
            if isfield(d,SchemaCallBy.fieldName)
                thisWrapper.(SchemaCallBy.fieldName) = d.(SchemaCallBy.fieldName);
                d = rmfield(d,SchemaCallBy.fieldName);
            end

            % Place the schema for this variable into the data field of the
            % invertible envelope. 
            thisWrapper.properties.data = d;
            d = thisWrapper;
        end

        % Save the declaration in a format that makes creating the output
        % structure easy.
        decl{i} = d;
        d = [];   % To allow it to be string or structure again.
    end

    % Structure with one field per argument. name -> (type, description)
    % Except description is empty right now -- to be filled in later.
    args = [ names; decl ];
    properties = struct(args{:});
    required = names(required);
    count = ParameterKind.CountType(kind);
    % How many positional arguments?
    pN = count(ParameterKind.Required) + count(ParameterKind.Optional);
    order = string(names(1:pN));
end

function [size,type,fcn,default] = argumentInfo(info)
% The argument information line (a string) consists of four optional parts:
% <size> <class> <validation> <default>
% <size> is delimited by ( ).
% <class> is a single string, with no spaces.
% <validation> is delimited by { }.
% <default> begins with =.

    import prodserver.mcp.internal.Constants

    % When erasing parts of the string, use the patterns instead of the
    % literal text in order to anchor the erasure to the beginning of the
    % string. In the info line 'string = string.empty' we must ONLY erase
    % the first 'string' or the default value will be set to '.empty',
    % which is invalid MATLAB code.

    size = extract(info,Constants.ParameterSizePattern);
    info = strtrim(erase(info,Constants.ParameterSizePattern));

    type = extract(info,Constants.TypePattern);
    info = strtrim(erase(info,Constants.TypePattern));

    fcn = extract(info,Constants.ValidationPattern);
    info = strtrim(erase(info,Constants.ValidationPattern));

    default = strtrim(extract(info,Constants.DefaultPattern));
end

function [pth,val] = nestedFieldValues(s,f)
% Recursively extract all field values and their full paths from field F of
% structure S. Both pth and val are cell arrays.
    if isstruct(s.(f))
        fields = string(fieldnames(s.(f)))';
        val = {};
        pth = {};
        for sf = fields
            [sp,v] = nestedFieldValues(s.(f),sf);
            for p = 1:numel(sp)
                sp{p} = [ {f}, sp{p} ]; 
            end
            pth = [ pth, sp ]; %#ok<AGROW>
            val = [ val, v ];  %#ok<AGROW>
        end
    else
        pth = { { f } } ;
        val = { s.(f) };
    end
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