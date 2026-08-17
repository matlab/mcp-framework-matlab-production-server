classdef SchemaObserver < handle
%SchemaObserver Accumulates JSON Schema fragments from observed function calls.
%   Used by prodserver.mcp.schema to record argument schemas during test
%   execution. Stored in getappdata(0, 'MCPSchemaObserver') so shadow
%   wrappers can access it.

% Copyright 2026 The MathWorks, Inc.

    properties(Access = private)
        Store dictionary = dictionary(string.empty, cell.empty)
        ArgCounts dictionary = dictionary(string.empty, cell.empty)
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
                obj.append(key, fragment);
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
                obj.append(key, fragment);
                idx = idx + 1;
            end
        end

        function definitions = harvest(obj, fcns, encoding)
        %harvest Deduplicate and merge fragments into definition structs.
        %   fcns     - String vector of function names that were observed.
        %   encoding - prodserver.mcp.WireEncoding value.
        %   Returns a struct array compatible with build(fcn, definition=X).

            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.metafunction
            import prodserver.mcp.internal.parameterDescription
            import prodserver.mcp.internal.toolDescription
            import prodserver.mcp.internal.ParameterKind
            import prodserver.mcp.internal.Constants

            if nargin < 3
                encoding = prodserver.mcp.WireEncoding.Invertible;
            end

            % Load wire encoding wrapper template if needed
            wrapper = struct.empty;
            if encoding == prodserver.mcp.WireEncoding.Invertible
                wrapper = fileread(fullfile( ...
                    prodserver.mcp.internal.packageFolder(), ...
                    "+prodserver","+mcp","+jsonrpc", ...
                    "wireEncodingArgTemplate.json"));
                wrapper = jsondecode(wrapper);
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

                % Tool description
                desc = toolDescription(mf);
                if encoding == prodserver.mcp.WireEncoding.Invertible
                    desc = desc + " " + MCPConstants.WireEncodingRequiredMsg;
                end
                def.tools.description = desc;

                % Extract parameter descriptions (lenient)
                [inDesc, outDesc, ~] = parameterDescription(mf, strict=false);

                % Build input schema and signatures
                [def.tools.inputSchema, inSig] = obj.buildSchema( ...
                    fcnName, "input", mf.Signature.Inputs, inDesc, ...
                    encoding, wrapper);

                % Build output schema and signatures
                [def.tools.outputSchema, outSig] = obj.buildSchema( ...
                    fcnName, "output", mf.Signature.Outputs, outDesc, ...
                    encoding, wrapper);

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

        function append(obj, key, fragment)
            if isKey(obj.Store, key)
                existing = obj.Store(key);
                obj.Store(key) = {[existing{1}, {fragment}]};
            else
                obj.Store(key) = {{fragment}};
            end
        end

        function [schema, sig] = buildSchema(obj, fcnName, io, signature, ...
                descriptions, encoding, wrapper)

            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.ParameterKind
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.jsonrpc.jsonParameterType

            schema.type = "object";
            isReqVec = false(1, numel(signature));
            kind = repmat(ParameterKind.Unknown, 1, numel(signature));
            names = cell(1, numel(signature));
            types = strings(1, numel(signature));
            group = [];
            validation = cell(1, numel(signature));
            default = [];

            if io == "input"
                wireMsg = MCPConstants.WireEncodingInputMsg;
            else
                wireMsg = MCPConstants.WireEncodingOutputMsg;
            end

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
                if isKey(obj.Store, key)
                    stored = obj.Store(key);
                    fragments = stored{1};
                    merged = obj.mergeFragments(fragments);
                else
                    merged.type = "object";
                end

                % Determine MATLAB type name for signatures
                matlabType = MCPConstants.DefaultArgType;
                if isfield(signature(i), 'Validation') && ...
                        ~isempty(signature(i).Validation) && ...
                        isfield(signature(i).Validation, 'Class') && ...
                        ~isempty(signature(i).Validation.Class)
                    matlabType = string(signature(i).Validation.Class.Name);
                end
                types(i) = matlabType;

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
                        % Sanitize: remove %#schema lines
                        keep = ~startsWith(paramDesc, Constants.Schema);
                        paramDesc = paramDesc(keep);
                        descStr = strjoin(paramDesc, newline);
                        hasComment = strlength(descStr) > 0;
                    else
                        hasComment = false;
                    end
                end
                if ~hasComment
                    descStr = prodserver.mcp.internal.generateDescription(signature(i));
                end

                % Add wire encoding explanation to description
                if encoding == prodserver.mcp.WireEncoding.Invertible
                    descStr = descStr + newline + wireMsg;
                end
                merged.description = descStr;

                % Apply wire encoding wrapper
                if ~isempty(wrapper) && encoding == prodserver.mcp.WireEncoding.Invertible
                    thisWrapper = wrapper;
                    thisWrapper.description = merged.description;
                    merged = rmfield(merged, "description");
                    thisWrapper.properties.data = merged;
                    merged = thisWrapper;
                end

                schema.properties.(char(argName)) = merged;
                isReqVec(i) = isRequired;
            end

            if ~isempty(signature)
                schema.required = names(isReqVec);
                [minArgs, maxArgs] = ParameterKind.NargRange(kind);
                schema.minProperties = minArgs;
                schema.maxProperties = maxArgs;
            end

            % Build signature struct
            if ~isempty(signature)
                sig.name = string(names(:));
                sig.type = types(:);
                sig.kind = kind;
                count = ParameterKind.CountType(kind);
                pN = count(ParameterKind.Required) + count(ParameterKind.Optional);
                sig.order = string(names(1:pN));
                sig.group = group;
                sig.validation = validation;
                sig.default = default;
            else
                sig = [];
            end
        end

        function merged = mergeFragments(~, fragments)
            % Deduplicate: remove identical fragments
            unique = fragments(1);
            for i = 2:numel(fragments)
                isDup = false;
                for j = 1:numel(unique)
                    if isequal(fragments{i}, unique{j})
                        isDup = true;
                        break;
                    end
                end
                if ~isDup
                    unique{end+1} = fragments{i}; %#ok<AGROW>
                end
            end

            if numel(unique) == 1
                merged = unique{1};
            else
                merged.anyOf = unique;
            end
        end

    end
end
