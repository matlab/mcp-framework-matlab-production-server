function [properties,required,kind,order,group,validation,default,types] = ...
    argumentDeclaration(args,parameters,encoding,stage,typemap,io)
% Extract argument names, types and descriptions from an argument
% block. Return an MCP properties structure and an array of the names of
% the required arguments. types is each argument's declared class, or ""
% if it has none, for the signature.
%
% All the returned types must be jsonencode-compatible, as they form part
% of the signature, which travels over the wire via JSONRPC. So no
% dictionaries, tempting as they may be.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.internal.SchemaOrigin

    if nargin < 5 || isempty(typemap)
        typemap = struct();
    end
    if nargin < 6
        io = "input";
    end

    names = cell(1,numel(args));
    decl = cell(size(names));
    required = false(size(names));
    kind = repmat(ParameterKind.Unknown,size(names));
    % Should be dictionaries, but must be struct due to JSON constraints.
    group = [];
    default = [];
    validation = cell(size(names));
    types = strings(size(names));

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
        declaredClass = hasField(args(i),"Validation.Class") && ...
            ~isempty(args(i).Validation.Class);
        if declaredClass
            t = args(i).Validation.Class.Name;
        end

        % Argument block validation typically specifies one or more of size
        % (shape), data type and value constraints (mustBePositive, for
        % example).
        [validation{i}, default.(names{i}), textClass] = ...
            prodserver.mcp.jsonrpc.argumentSignature(parameters(names{i}));
        if textClass ~= ""
            t = textClass;
            declaredClass = true;
        end

        % The signature's type is the declared class. Not the schema's,
        % which takes MCPConstants.DefaultArgType when there is none.
        if declaredClass
            types(i) = string(t);
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
        % structure will include the "minItems" and "maxItems" fields (both
        % with value 6 in this case.)
        %
        % For scalar parameters (where the size is explicitly (1,1)):
        %   {
        %       "type": "<MATLAB type name>" 
        %   }
        %
        % Some MCP hosts appear to validate against the schema. Others do
        % not. YMMV. For the ones that do, the schema must be correct.

        % A class with no plain JSON type has a schema of its own, if the
        % encoding can carry it at all. The schema is the whole encoded
        % value, so it takes no invertible envelope.
        wireClass = "";
        sz = [];
        if hasField(args(i),"Validation.Size")
            sz = args(i).Validation.Size;
        end
        % A char row vector is one string, as on the example path.
        text = prodserver.mcp.jsonrpc.isCharText(string(t), sz);
        if prodserver.mcp.jsonrpc.WireSupport.of(t, typemap) ~= ...
                prodserver.mcp.jsonrpc.WireSupport.JSON
            wireClass = string(t);
            d = prodserver.mcp.jsonrpc.classSchema(names{i}, wireClass, ...
                encoding, typemap=typemap, size=sz);
        elseif text
            d.type = t;
        else
            d.type = "array";
            d.items.type = t;
        end

        % Validation may indicate the size of one or more dimensions: a
        % scalar, or an array of an exact or unrestricted count.
        if wireClass == "" && ~text
            d = prodserver.mcp.jsonrpc.declaredSizeSchema(d, sz, string(t));
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
            % The user-specified schema may either add to or replace the
            % autogenerated schema.
            [d, replaced] = prodserver.mcp.jsonrpc.injectSchema(d, schema, names{i}, encoding);
            if replaced
                wireClass = "";
            end
            % A class schema is the whole encoded value, not a wrapper's
            % data, and may be a union of its forms.
            if wireClass == ""
                requireSingleType(d, names{i}, encoding);
            end
        end
        % Whence did the schema originate?
        d.schema.origin = parameters(names{i}).schema.origin;

        % Format description appropriately for schema.
        d.description = prodserver.mcp.internal.descriptionText( ...
            parameters(names{i}).description, stage);

        % Record the MATLAB class of a schema of classSchema's, for the
        % signature and so that mcpArgumentTypes leaves the JSON types
        % alone. Then the externalized examples, and the invertible
        % envelope or annotation.
        if wireClass ~= ""
            d.schema.matlabClass = wireClass;
        end
        % The wrapper's type tag: the declared class, unless there is none
        % or a typemap maps it.
        % With no class, the validators may admit only some.
        tagClass = string.empty;
        if declaredClass && ~isfield(typemap, string(t))
            tagClass = string(t);
        end
        admitted = string.empty;
        if ~declaredClass && hasField(parameters(names{i}), "validation")
            admitted = prodserver.mcp.jsonrpc.validatorClasses( ...
                parameters(names{i}).validation);
        end
        d = prodserver.mcp.jsonrpc.finishParameterSchema(d, encoding, ...
            wireClass ~= "", ...
            prodserver.mcp.jsonrpc.wrapperTypeSchema(tagClass, io, admitted));

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
    order = ParameterKind.PositionalOrder(names, kind);
end

function requireSingleType(d, name, encoding)
% Error unless schema D, the %#schema of the parameter NAME merged with the
% generated schema (or in its place), has a single "type", under the
% invertible ENCODING. There the schema describes the wrapper's data, whose
% elements need one type. Under plain JSON, a union (anyOf or oneOf, no
% type) or a list of types is used as given: mcpArgumentTypes has no type
% to reconcile with the declaration, and leaves it alone. The same goes
% for a list of types in the items of an array.
    single = @(t) ischar(t) || (isstring(t) && isscalar(t));
    listed = @(t) strjoin("""" + string(t(:)') + """", ", ");
    if isfield(d, 'type') && single(d.type)
        if ~prodserver.mcp.internal.hasField(d, "items.type") || single(d.items.type)
            return
        end
        found = "lists " + listed(d.items.type) + " for its items";
    elseif isfield(d, 'type')
        found = "lists " + listed(d.type);
    else
        found = "has none";
    end
    if encoding ~= prodserver.mcp.WireEncoding.Invertible
        return
    end
    error("prodserver:mcp:InvalidParameterSchema", ...
        "Invalid schema for parameter '%s': under encoding=""Invertible"", " + ...
        "a parameter declared in an arguments block needs a single " + ...
        """type"" in its %%#schema, such as ""number"" or ""array"", " + ...
        "because the schema describes the elements of the wrapper's " + ...
        "data, but this one %s. Add a ""type"", or build the tool with " + ...
        "encoding=""JSON"", which publishes the schema as given.", name, found);
end
