classdef SchemaObserver < handle
%SchemaObserver Accumulates JSON Schema fragments from observed function calls.
%   Used by prodserver.mcp.schema to record argument schemas during test
%   execution. Stored in getappdata(0, 'MCPSchemaObserver') so shadow
%   wrappers can access it.

% Copyright 2026 The MathWorks, Inc.

    properties(Access = private)
        Store dictionary = dictionary(string.empty, cell.empty)
        ArgCounts dictionary = dictionary(string.empty, cell.empty)
        % The MATLAB classes observed for each parameter, for the wrapper's
        % type tag: schemaFromValue keeps only the JSON type.
        Classes dictionary = dictionary(string.empty, cell.empty)
        TypeMap struct
    end

    methods

        function obj = SchemaObserver(typemap)
        %SchemaObserver Construct observer with optional type map.
        %   typemap - struct with MATLAB type names as fields and JSON type
        %   names as values (same format as build()'s opts.typemap). If
        %   empty or omitted, uses default mappings from jsonParameterType.

            if nargin < 1 || isempty(typemap)
                obj.TypeMap = struct();
            else
                obj.TypeMap = typemap;
            end
        end

        function record(obj, fcnName, io, argNames, args, nPositional)
        %record Record schema fragments for one function call.
        %   fcnName     - Name of the observed function (string)
        %   io          - "input" or "output" (string)
        %   argNames    - Names of arguments (string vector)
        %   args        - Cell array of argument values (varargin/varargout)
        %   nPositional - Number of positional arguments

            import prodserver.mcp.jsonrpc.schemaFromValue

            % Record positional arguments
            nArgs = min(nPositional, numel(args));
            for i = 1:nArgs
                key = fcnName + "." + io + "." + argNames(i);
                fragment = schemaFromValue(args{i}, obj.TypeMap);
                obj.append(key, fragment, class(args{i}));
            end

            % Record observed positional arg count
            countKey = fcnName + "." + io;
            if isKey(obj.ArgCounts, countKey)
                existing = obj.ArgCounts(countKey);
                existing{1}(end+1) = nArgs;
                obj.ArgCounts(countKey) = existing;
            else
                obj.ArgCounts(countKey) = {nArgs};
            end

            % Record NVP arguments (trailing name/value pairs after positional)
            idx = nPositional + 1;
            while idx < numel(args)
                nvpName = args{idx};
                if ~(ischar(nvpName) || isstring(nvpName))
                    break;
                end
                nvpName = string(nvpName);
                idx = idx + 1;
                if idx > numel(args)
                    break;
                end
                key = fcnName + "." + io + "." + nvpName;
                fragment = schemaFromValue(args{idx}, obj.TypeMap);
                obj.append(key, fragment, class(args{idx}));
                idx = idx + 1;
            end
        end

        function definitions = harvest(obj, fcns, encoding)
        %harvest Deduplicate and merge fragments into definition structs.
        %   fcns     - String vector of function names that were observed.
        %   encoding - prodserver.mcp.WireEncoding value: one for every
        %              function, or one per function. The examples ran
        %              once; only the schemas built from them differ.
        %   Returns a struct array compatible with build(fcn, definition=X).

            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.metafunction
            import prodserver.mcp.internal.parameterDescription
            import prodserver.mcp.internal.toolDescription
            import prodserver.mcp.internal.ParameterKind
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.jsonrpc.argumentSchema

            if nargin < 3
                encoding = prodserver.mcp.WireEncoding.Invertible;
            end
            if isscalar(encoding)
                encoding = repmat(encoding, size(fcns));
            end

            definitions = struct([]);
            for fi = 1:numel(fcns)
                fcnName = fcns(fi);

                % Verify the function was actually called during observation
                inputKey = fcnName + ".input";
                if ~isKey(obj.ArgCounts, inputKey)
                    error("prodserver:mcp:SchemaNoObservation", ...
                        "Function '%s' was never called during test " + ...
                        "execution. The test must exercise every function " + ...
                        "passed to schema().", fcnName);
                end

                mf = metafunction(fcnName);

                def = struct();
                def.tools.name = fcnName;

                % The tool description comes after the schemas: it leaves
                % out the help-text lines that became parameter
                % descriptions. Assign it here to keep the field order.
                def.tools.description = "";
                helpParams = prodserver.mcp.internal.helpParameters(mf);

                % Extract parameter descriptions (lenient)
                [inDesc, outDesc, ~] = parameterDescription(mf, strict=false);

                % Parse %#schema annotations from comments
                if ~isempty(inDesc)
                    inDesc = argumentSchema(inDesc);
                end
                if ~isempty(outDesc)
                    outDesc = argumentSchema(outDesc);
                end

                % Build input schema and signatures
                [def.tools.inputSchema, inSig, inUsed, inUnknown] = obj.buildSchema( ...
                    fcnName, "input", mf.Signature.Inputs, inDesc, ...
                    encoding(fi), helpParams);

                % Build output schema and signatures
                [def.tools.outputSchema, outSig, outUsed, outUnknown] = obj.buildSchema( ...
                    fcnName, "output", mf.Signature.Outputs, outDesc, ...
                    encoding(fi), helpParams);

                % Say which parameters the schema can't describe, so the
                % author can exercise or declare them.
                unknown = [inUnknown, outUnknown];
                if ~isempty(unknown)
                    warning("prodserver:mcp:UnobservedParameters", ...
                        "No example call exercised %s of '%s', and " + ...
                        "%s no declared class, so %s a value of any " + ...
                        "type. Add an example that passes or requests " + ...
                        "%s, or declare %s class in an arguments block.", ...
                        "'" + strjoin(unknown, "', '") + "'", fcnName, ...
                        pick(unknown, "it has", "they have"), ...
                        pick(unknown, "its schema allows", "their schemas allow"), ...
                        pick(unknown, "it", "them"), ...
                        pick(unknown, "its", "each one's"));
                end

                % Tool description
                desc = toolDescription(mf, exclude=[inUsed, outUsed]);
                def.tools.description = ...
                    prodserver.mcp.internal.encodingDescription(desc, encoding(fi));

                % Build signatures
                def.signatures.(fcnName).function = mf.Name;
                if ~isempty(inSig)
                    def.signatures.(fcnName).input = inSig;
                end
                if ~isempty(outSig)
                    def.signatures.(fcnName).output = outSig;
                end

                if isempty(definitions)
                    definitions = def;
                else
                    definitions(end+1) = def; %#ok<AGROW>
                end
            end
        end

    end

    methods(Access = private)

        function append(obj, key, fragment, matlabClass)
            if isKey(obj.Store, key)
                existing = obj.Store(key);
                obj.Store(key) = {[existing{1}, {fragment}]};
            else
                obj.Store(key) = {{fragment}};
            end
            if isKey(obj.Classes, key)
                seen = obj.Classes(key);
                obj.Classes(key) = {unique([seen{1}, string(matlabClass)], "stable")};
            else
                obj.Classes(key) = {string(matlabClass)};
            end
        end

        function [schema, sig, helpUsed, unknown] = buildSchema(obj, ...
                fcnName, io, signature, descriptions, encoding, helpParams)
        %buildSchema helpUsed names the parameters whose description came
        %from a help-text line in helpParams. unknown names those whose
        %type nothing determined: no example exercised them, and they have
        %no declared class. Their schemas don't constrain the type.

            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.ParameterKind
            import prodserver.mcp.internal.SchemaOrigin
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.jsonrpc.jsonParameterType

            helpUsed = string.empty;
            unknown = string.empty;
            props = struct();
            isReqVec = false(1, numel(signature));
            kind = repmat(ParameterKind.Unknown, 1, numel(signature));
            names = cell(1, numel(signature));
            types = strings(1, numel(signature));
            group = [];
            validation = cell(1, numel(signature));
            default = [];

            % Determine if function has an argument block by checking
            % whether any parameter has validation metadata.
            hasArgBlock = ~isempty(signature) && ...
                any(~cellfun(@isempty, {signature.Validation}));

            % For inputs without an argument block, use observed call
            % counts to infer requiredness. For outputs, always trust
            % metadata (outputs are driven by caller's nargout).
            countKey = fcnName + "." + io;
            useObservedCounts = ~hasArgBlock && io == "input";
            if useObservedCounts && isKey(obj.ArgCounts, countKey)
                counts = obj.ArgCounts(countKey);
                minObserved = min(counts{1});
            else
                minObserved = 0;
            end

            for i = 1:numel(signature)
                argName = string(signature(i).Identifier.Name);
                names{i} = char(argName);
                key = fcnName + "." + io + "." + argName;

                % Determine type from observation or metadata
                observed = isKey(obj.Store, key);
                if observed
                    stored = obj.Store(key);
                    fragments = stored{1};
                    merged = obj.mergeFragments(fragments);
                end

                % Determine MATLAB type name for signatures
                matlabType = MCPConstants.DefaultArgType;
                declaredClass = hasField(signature(i), "Validation.Class") && ...
                    ~isempty(signature(i).Validation.Class);
                if declaredClass
                    matlabType = string(signature(i).Validation.Class.Name);
                end
                types(i) = matlabType;

                declaredSize = [];
                if hasField(signature(i), "Validation.Size")
                    declaredSize = signature(i).Validation.Size;
                end

                % Never observed: an input no example passed, or an output
                % none asked for. A declared class says what it is, as on
                % the declared path; otherwise nothing does, and the schema
                % must not claim a type. Always a fresh schema, never the
                % previous parameter's.
                if ~observed
                    merged = struct();
                    if declaredClass
                        jsonType = jsonParameterType(matlabType, obj.TypeMap);
                        if strlength(jsonType) > 0
                            merged.type = jsonType;
                            if isempty(declaredSize) && ...
                                    ~isTextScalar(matlabType, merged, declaredSize)
                                % No size: MATLAB's default, an array.
                                merged = struct('type', "array", 'items', merged);
                            end
                        end
                    else
                        unknown(end+1) = argName; %#ok<AGROW>
                    end
                end

                % A class JSON can't describe has a schema of its own, if
                % the encoding can carry it at all. complete means merged
                % is then a whole encoded value, not a wrapper's data.
                if declaredClass && prodserver.mcp.jsonrpc.WireSupport.of( ...
                        matlabType, obj.TypeMap) ~= prodserver.mcp.jsonrpc.WireSupport.JSON
                    merged = prodserver.mcp.jsonrpc.classSchema(argName, ...
                        matlabType, encoding, typemap=obj.TypeMap, ...
                        size=declaredSize);
                    complete = true;
                else
                    [merged, complete] = resolveWireTypes(merged, argName, ...
                        encoding, obj.TypeMap, declaredSize);
                end

                % Apply size constraints from argument block validation,
                % with the JSON type, never the MATLAB class name: the
                % example path has no later step to convert it.
                if ~complete && ~isTextScalar(matlabType, merged, declaredSize)
                    scalarType = "";
                    if observed || declaredClass
                        scalarType = jsonParameterType(matlabType, obj.TypeMap);
                    end
                    merged = prodserver.mcp.jsonrpc.declaredSizeSchema( ...
                        merged, declaredSize, scalarType);
                end

                % Apply %#schema injection from argument block comments.
                if ~isempty(descriptions) && isKey(descriptions, argName) ...
                        && isfield(descriptions(argName), 'schema') ...
                        && descriptions(argName).schema.origin ~= SchemaOrigin.Introspection
                    [merged, replaced] = prodserver.mcp.jsonrpc.injectSchema( ...
                        merged, descriptions(argName).schema, argName);
                    if replaced
                        complete = false;
                    end
                end

                % Determine requiredness and ParameterKind
                if useObservedCounts
                    isRequired = (i <= minObserved);
                    if isRequired
                        kind(i) = ParameterKind.Required;
                    else
                        kind(i) = ParameterKind.Optional;
                    end
                else
                    isRequired = signature(i).Required;
                    kind(i) = ParameterKind.FromMetaData( ...
                        isRequired, signature(i).Identifier);
                end

                % Group membership
                group.(char(argName)) = string(signature(i).Identifier.GroupName);

                % Validation and default (from argument block if available)
                validation{i} = [];
                default.(char(argName)) = "";

                % Compose description
                hasComment = ~isempty(descriptions) && isKey(descriptions, argName);
                if hasComment
                    paramDesc = descriptions(argName).description;
                    if ~isempty(paramDesc) && any(strlength(paramDesc) > 0)
                        descStr = prodserver.mcp.internal.descriptionText( ...
                            paramDesc, prodserver.mcp.BuildStage.Definition);
                        hasComment = strlength(descStr) > 0;
                    else
                        hasComment = false;
                    end
                end
                % No comment in an arguments block: a help-text line, else
                % a description generated from the name and declaration.
                helpI = [];
                if ~hasComment && ~isempty(helpParams)
                    helpI = find([helpParams.name] == argName, 1);
                end
                if ~isempty(helpI)
                    descStr = helpParams(helpI).text;
                    helpUsed(end+1) = argName; %#ok<AGROW>
                elseif ~hasComment
                    descStr = prodserver.mcp.internal.generateDescription( ...
                        signature(i), io);
                end

                % Add wire encoding explanation to description
                if encoding == prodserver.mcp.WireEncoding.Invertible
                    descStr = strjoin(prodserver.mcp.jsonrpc.withWireEncodingMsg( ...
                        split(string(descStr), newline), io), newline);
                end
                merged.description = descStr;

                % Externalized examples, then the invertible envelope or
                % annotation. A complete schema already describes the whole
                % encoded value. The envelope's type tag is the declared
                % class, else what the validators admit, else the observed
                % classes (see wrapperTypeSchema).
                if declaredClass
                    tagClasses = matlabType;
                elseif isKey(obj.Classes, key)
                    tagClasses = obj.Classes(key);
                    tagClasses = tagClasses{1};
                else
                    tagClasses = string.empty;
                end
                if any(isfield(obj.TypeMap, cellstr(tagClasses)))
                    tagClasses = string.empty;
                end
                admitted = string.empty;
                if ~declaredClass && ~isempty(descriptions) && ...
                        isKey(descriptions, argName) && ...
                        isfield(descriptions(argName), 'validation')
                    admitted = prodserver.mcp.jsonrpc.validatorClasses( ...
                        descriptions(argName).validation);
                end
                % Validators say what the parameter admits; examples only
                % what it was given.
                if ~isempty(admitted)
                    tagClasses = string.empty;
                end
                merged = prodserver.mcp.jsonrpc.finishParameterSchema( ...
                    merged, encoding, complete, ...
                    prodserver.mcp.jsonrpc.wrapperTypeSchema(tagClasses, io, admitted));
                % And the bare forms, unless the declared size says it's
                % never a scalar. Only the invertible encoding has a
                % wrapper; under JSON, a struct with a data field is just
                % a struct.
                if encoding == prodserver.mcp.WireEncoding.Invertible
                    merged = prodserver.mcp.jsonrpc.allowBareForms(merged, ...
                        prodserver.mcp.jsonrpc.WireShape.fromSize(declaredSize));
                end

                props.(char(argName)) = merged;
                isReqVec(i) = isRequired;
            end

            schema = prodserver.mcp.internal.parameterObject(props, ...
                names(isReqVec), kind);

            % Build signature struct
            if ~isempty(signature)
                sig.name = string(names(:));
                sig.type = types(:);
                sig.kind = kind;
                sig.order = ParameterKind.PositionalOrder(names, kind);
                sig.group = group;
                sig.validation = validation;
                sig.default = default;
            else
                sig = [];
            end
        end

        function merged = mergeFragments(~, fragments)
            % The distinct fragments: one schema, or an anyOf of them.
            merged = prodserver.mcp.jsonrpc.anyOfSchema(fragments);
        end

    end
end

function word = pick(names, one, many)
% The word that agrees with how many NAMES there are.
    if isscalar(names)
        word = one;
    else
        word = many;
    end
end

function tf = isTextScalar(matlabType, schema, declaredSize)
% A char row vector is one JSON string, not an array (see isCharText). A
% string-typed observation with no declared class is ambiguous; treat it
% as char.
    if nargin < 3
        declaredSize = [];
    end
    tf = prodserver.mcp.jsonrpc.isCharText(matlabType, declaredSize) || ...
        (~ismember(matlabType, ["char" "string"]) && isfield(schema, 'type') && ...
         strcmpi(schema.type, "string"));
end

function [node, complete] = resolveWireTypes(node, path, encoding, typemap, declaredSize)
% Resolve the class tags schemaFromValue leaves for values JSON can't
% describe. Error if the encoding can't carry the class; otherwise use the
% invertible encoding's schema for it. path names the node in messages.
% complete is true when the node is now a whole encoded value rather than
% the data of a wrapper. declaredSize, if given, overrides the observed
% shape of a tag at the top level.
    if nargin < 5
        declaredSize = [];
    end
    C = prodserver.mcp.internal.Constants;
    complete = false;
    if ~isstruct(node)
        return
    end

    if isfield(node, C.ClassTag)
        node = prodserver.mcp.jsonrpc.classSchema(path, node.(C.ClassTag), ...
            encoding, typemap=typemap, size=declaredSize, shape=tagShape(node));
        complete = true;
        return
    end

    if isfield(node, 'anyOf')
        branches = prodserver.mcp.jsonrpc.schemaAlternatives(node);
        classes = strings(size(branches));
        for k = 1:numel(branches)
            classes(k) = tagClass(branches{k});
        end
        % Examples of one class in both shapes: one schema covers both.
        if all(classes ~= "") && all(classes == classes(1))
            node = prodserver.mcp.jsonrpc.classSchema(path, classes(1), ...
                encoding, typemap=typemap, size=declaredSize);
            complete = true;
            return
        end
        % Mixed classes across examples. If only some branches are
        % complete, the wrapper around the rest is approximate.
        done = false(size(branches));
        for k = 1:numel(branches)
            [branches{k}, done(k)] = resolveWireTypes(branches{k}, path, ...
                encoding, typemap);
        end
        node.anyOf = branches;
        complete = all(done);
        return
    end

    if isfield(node, 'properties') && isstruct(node.properties)
        f = string(fieldnames(node.properties))';
        for k = f
            node.properties.(k) = resolveWireTypes(node.properties.(k), ...
                path + "." + k, encoding, typemap);
        end
    end
    if isfield(node, 'items')
        node.items = resolveWireTypes(node.items, path + "(:)", ...
            encoding, typemap);
    end
    if isfield(node, C.ElementsTag)
        % Check the tagged cell elements; the cell schema doesn't list them.
        for k = 1:numel(node.(C.ElementsTag))
            resolveWireTypes(node.(C.ElementsTag){k}, path + "{:}", ...
                encoding, typemap);
        end
        node = rmfield(node, C.ElementsTag);
    end
end

function c = tagClass(node)
    C = prodserver.mcp.internal.Constants;
    c = "";
    if isstruct(node) && isfield(node, C.ClassTag)
        c = string(node.(C.ClassTag));
    end
end

function shape = tagShape(node)
% The observed shape. A declared size, if any, overrides it in classSchema.
    if node.(prodserver.mcp.internal.Constants.ScalarTag)
        shape = prodserver.mcp.jsonrpc.WireShape.Scalar;
    else
        shape = prodserver.mcp.jsonrpc.WireShape.Array;
    end
end
