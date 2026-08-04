function [properties,required,kind,order,group,validation,default] = ...
    argumentDeclaration(args,parameters,encoding,stage)
% Extract argument names, types and descriptions from an argument
% block. Return an MCP properties structure and an array of the names of
% the required arguments.
%
% All the returned types must be jsonencode-compatible, as they form part
% of the signature, which travels over the wire via JSONRPC. So no
% dictionaries, tempting as they may be.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.internal.SchemaInjection
    import prodserver.mcp.internal.SchemaOrigin
    import prodserver.mcp.jsonrpc.SchemaCallBy
    import prodserver.mcp.internal.nestedFieldValues
    import prodserver.mcp.jsonrpc.isExternalized

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

        % Format description appropriately for schema.
        d.description = sanitizeDescription(parameters(names{i}).description,...
            stage);

        % Annotate each externalized parameter with examples of valid URLs.
        % Explicitly supported by JSONSchema.
        if isExternalized(d)
            d.examples = MCPConstants.ByReferenceExample;
        end

        % If we're using the invertible wire encoding, wrap the argument in
        % the invertible envelope. Never wrap externalized arguments, as
        % they are scalar strings.
        if ~isempty(wrapper) && isExternalized(d) == false
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

function d = sanitizeDescription(d,stage)
% Maintain line breaks of description. If the stage is "Definition", 
% remove build-time pragmas.
    import prodserver.mcp.internal.Constants
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
    d = strjoin(d,newline);
end