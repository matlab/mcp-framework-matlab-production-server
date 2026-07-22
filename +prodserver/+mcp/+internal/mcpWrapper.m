function [code,indirect] = mcpWrapper(fcn,tool,opts)
%mcpWrapper Generate a wrapper named tool from the function in fcn.
%
%    [code,indirect] = mcpWrapper(fcn,tool,opts) returns CODE of a wrapper
%        function named TOOL for FCN incorporating import options and type
%        definitions specified in OPTS. INDIRECT contains the schemas for
%        externalized input and output parameters -- descriptions of the
%        data stored AT the external locations, the "indirect" value of the
%        parameter. (Because the actual value of an external parameter is
%        always a string.)

% Copyright 2025-2026 The MathWorks, Inc.

    % All inputs pre-validated by caller. arguments block used instead of
    % inputParser for convenience and readability.
    arguments
        fcn   % Absolute or relative path to the deployable function
        tool  % Name to use for the wrapper function
        % Names of variables with explicit importers. 
        opts.import string = string.empty
        % Maximum size of literal variable.
        opts.maxLiteralSize = prodserver.mcp.MCPConstants.MaxLiteralSize
        % Map of MATLAB type names to JSON type names
        opts.typemap struct = [];
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.parameterDescription
    
    if exist(fcn,"file") == false
        error("prodserver:mcp:ToolFcnNotFound", "MCP function %s " + ...
            "not found.", fcn);
    end
    
    % MATLAB meta-data for the function. Most, but not all, of the
    % information necessary to construct the wrapper.
    mf = prodserver.mcp.internal.metafunction(fcn);
    if isempty(mf)
        error("prodserver:mcp:CannotParseToolFcn", "Cannot parse MCP " + ...
            "function file %s. Verify that the file contains at least one " + ...
            "MATLAB function.", fcn);
    end

    % Get the MCP tool definition for the function. This provides access to
    % the schema for each parameter, which we use to determine if the
    % parameter is call-by-value or call-by-reference.
    td = prodserver.mcp.internal.mcpDefinition(tool,fcn,...
        typemap=opts.typemap,stage=prodserver.mcp.BuildStage.Wrapper);

    % Determine which inputs and outputs are to be passed as literals. We
    % distinguish between "literal" and "externalized" -- literal data is
    % embedded in the tools/call request while externalized data has only
    % the *location* of the data embedded in the tools/call request.
    %
    % Require argument block entries for all inputs and outputs.

    [isLiteralIn, namesIn] = findLiterals(mf.Signature.Inputs,...
        td.tools.inputSchema);

    [isLiteralOut, namesOut] = findLiterals(mf.Signature.Outputs,...
        td.tools.outputSchema);

    % Form output parameter list from names of all literal outputs.
    literalOut = namesOut(isLiteralOut);
    outParamList = "";
    if ~isempty(literalOut)
        outParamList = "[" + strjoin(literalOut,",") + "] = ";
    end

    % Add external suffix to externalized input parameters
    externIn = namesIn(~isLiteralIn) + MCPConstants.ExternalParamSuffix;

    % Form list of externalized output parameter names.
    externOut = setdiff(namesOut,literalOut,'stable') + ...
        MCPConstants.ExternalParamSuffix; 

    % Capture the schemas of variables that will be externalized, and
    % modify their descriptions.
    [indirect, td.tools] = externalizeParameters(td.tools,...
        namesIn(~isLiteralIn), externIn, ...
        namesOut(~isLiteralOut), externOut);

    % Merge tool description and signature data into a single structure
    % used for subsequent code generation.

    inParams = toolParameters(td.signatures.(tool).input,td.tools.inputSchema);
    outParams = toolParameters(td.signatures.(tool).output,td.tools.outputSchema);

    % Form input parameter list from original input names and a new group
    % for externalized output parameters. For input arguments that belong 
    % to a group, only add the group to the parameter list. (And put the 
    % group name at the end of the list.)

    inParamList = namesIn; 
    inParamList(~isLiteralIn) = externIn;

    groupList = string.empty;
    groupIn = false;
    if ~isempty(inParams)
        groupIn = strlength([inParams.group])>0;
        if any(groupIn)
            groupList = [inParams.group]; groupList = groupList(groupIn);
            groupList = unique(groupList,"stable");
            inParamList = inParamList(~groupIn);
        end
    end

    % Determine unique optional parameter group name for externalized
    % output variables.
    externOutGroup = string.empty;
    if ~isempty(externOut)
        % Make sure group name for externalized output parameters (which
        % appears in the input argument list) does not conflict with the
        % name of any user-specified input parameter.
        uniqArgs = matlab.lang.makeUniqueStrings(...
            [inParamList, groupList, MCPConstants.ExternOutGroup]);
        externOutGroup = uniqArgs(end);
    end

    inParamList = [ inParamList, groupList, externOutGroup ];

    if ~isempty(inParamList)
        inParamList = "(" + strjoin(inParamList,",") + ")";
    end

    indent = "    ";

    % Function line!
    code = "function " + outParamList + tool + inParamList + newline;

    %
    % Tool description
    %
    % comment = string(mf.Description);
    % if ~isempty(mf.DetailedDescription)
    %     dd = string(split(mf.DetailedDescription,newline));
    %     comment = [comment; dd];
    % end
    comment = string(td.tools.description);

    % If there are any name-value pairs in argument groups, add a comment
    % explaining how to pass these arguments -- but check first to avoid
    % adding the comment twice, since optional input arguments in the
    % original function may have caused mcpDefinition to augment the
    % description already. Look for the first line of a the
    % OptionalGroupMsg, on the theory that it's unique.
    if ~isempty(externOut) && ...
            all(contains(comment,MCPConstants.OptionalGroupMsg{1}) == false)
        comment = [ comment; string(MCPConstants.OptionalGroupMsg) ];
    end

    comment = textwrap(comment, MCPConstants.WrapTextLen);
    comment = strjoin("% " + comment,newline);
    if isempty(comment) || strlength(comment) == 0
        error("prodserver:mcp:NoDescription", ...
            "Descriptive comment not found in %s. Add comment " + ...
            "describing the purpose of the tool: the LLM uses the comment " + ...
            "to determine when to use this tool.", mf.FullPath);
    end
    code = code + comment + newline;

    %
    % Argument blocks
    %

    % Reorganize to reflect externalization -- externalized inputs have new
    % names, externalized outputs have new name AND move to inputs. All
    % externalized arguments validate as scalar strings.

    % Change names of all externalized inputs -- including optional inputs.
    for n = 1:numel(namesIn)
        if isLiteralIn(n) == false

            % All URLs are scalar strings. 
            % value.
            info.size = "(1,1)";
            info.type = "string"; 
            info.fcn = "";

            % If this is an optional parameter, it must have a new default:
            % zero-length string, because all URLs are strings.
            if strlength(inParams(n).group) > 0
                inParams(n).default = """""";
            end

            % If this parameter was originally an optional name/value pair,
            % it will have the string "NVP: <group>.<name> in the description.
            % Find this string and change <name> to <name>URL.
            re = "(" + MCPConstants.NVPTag + ":\s+[^.]+[.]\w+)";
            inParams(n).description = regexprep(inParams(n).description, ...
                re,"$1"+MCPConstants.ExternalParamSuffix);

            inParams(n).info = info;
            inParams(n).name = inParams(n).name+MCPConstants.ExternalParamSuffix;
        end
    end

    % Move all externalized outputs to the input argument block, renaming
    % them in the process.
    for n = 1:numel(namesOut)
        if isLiteralOut(n) == false

            % All URLs are scalar strings. 
            % value.
            info.size = "(1,1)";
            info.type = "string"; 
            info.fcn = "";

            % Changing the data type from ?? to external sink, which is a
            % URL, which is a scalar string.
            outParams(n).info = info;

            % All externalized outputs belong to an optional input group.
            outParams(n).group = externOutGroup;
            outParams(n).name = outParams(n).name+MCPConstants.ExternalParamSuffix;

            % All externalized outputs have a default zero length string
            % value -- default value required to make the output optional.
            outParams(n).default = """""";
        end
    end

    % Remove all externalized output parameters from the output parameter
    % list.
    extOutParams = outParams(isLiteralOut == false); 
    extOutParams = extOutParams(:);  % Ensure column vector
    outParams(isLiteralOut == false) = [];

    % Form the input argument list for the wrapper function: all inputs
    % (externalized and untouched) followed by a group for externalized
    % outputs and then by user-specified group(s) for name-value pairs. 
    wrapIn = namesIn;
    wrapIn(~isLiteralIn) = externIn;
    nvpIn = string.empty;
    if any(groupIn)
        nvpIn = wrapIn(groupIn);
        wrapIn = wrapIn(~groupIn);
    end
    % Make sure elements of the first two arguments are in the same order.
    code = code + argumentBlock([wrapIn, nvpIn, externOut],...
        [inParams; extOutParams], "Input",indent);

    % Form the output argument list for the wrapper function: only
    % non-externalized (untouched) outputs.
    wrapOut = namesOut(isLiteralOut);
    code = code + argumentBlock(wrapOut,outParams,"Output",indent);

    % Declare marshaler if any externalized inputs or outputs
    if ~isempty(externOut) || ~isempty(externIn)
        % Ugly but unique
        mVar = "v" + replace(matlab.lang.internal.uuid,"-","_");
        code = code + indent + mVar + " = prodserver.mcp.io.MarshallURI();" + ...
            newline;
    end

    %
    % Deserialize inputs
    %

    % Local variables. Make sure they are unique here.
    optInVar = "optIn";
    importVar = "urlImport";
    defVar = "defFile";

    origName = erase(externIn, MCPConstants.ExternalParamSuffix + ...
        textBoundary("end"));
    if numel(externIn) > 0
        code = code + indent + "% deserialize always returns a cell " + ...
            "array." + newline;
        % If any of the inputs have an importer, load the importer variable
        % from the tool definition file.
        if ~isempty(opts.import)
            defVar = uniqueLocalVariable(inParams, outParams, defVar);
            importVar = uniqueLocalVariable(inParams, outParams, importVar);

            code = code + indent + defVar + " = matfile(""" + ...
                MCPConstants.DefinitionFile + """);" + newline;
            code = code + indent + importVar + " = " + defVar + "." + ...
                MCPConstants.ImporterVariable + ";" + newline;
        end

        % ~isScalarIn identifies the externalized inputs. groupIn
        % identifies the "grouped" optional inputs. If the intersection is
        % non-empty, there's extra work to do.
        if any(~isLiteralIn & groupIn)
            % Externalized optional inputs are passed to the original
            % function as name-value pairs. Because we don't know how many
            % there might be, declare a cell array here to populate with
            % any that are actually provided.
            optInVar = uniqueLocalVariable(inParams, outParams, optInVar);
            optInVar = optInVar(end);
            code = code + indent + optInVar + " = {};" + newline;
        end
    end

    extInParams = [];
    if numel(inParams) > 0
        extInParams = inParams(ismember([inParams.name],externIn));
    end
    for n = 1:numel(extInParams)
        % Deserialize and unwrap -- deserialize always returns a cell
        % array.
        d = extInParams(n);

        importThisVar = "";
        if ismember(origName(n),opts.import)
            % Additional argument to deserialize. Don't forget the
            % comma. Fetch the importer from the import structured
            % loaded from the tool definition file.
            importThisVar = ", import=" + importVar + "." + origName(n);

        end

        if strlength(d.group) > 0
            group = d.group+".";

            % If the URL is a string with non-zero length
            code = code + indent + "if strlength(" + group + externIn(n) + ...
                ") > 0" + newline;

            % Deserialize the URL data and add it to the cell array.
            code = code + indent + indent + optInVar + " = [ " + ...
                optInVar + ", {""" + origName(n) + """}" + ...
                ", deserialize(" + mVar + "," + group + externIn(n) + ...
                importThisVar + ")];" + newline;

            % Close if-statement
            code = code + indent + "end" + newline;

        else
            code = code + indent + origName(n) + " = deserialize(" + ...
                mVar + "," + extInParams(n).name + importThisVar + ");" + newline;
            code = code + indent + origName(n) + " = " + origName(n) + ...
                "{1};" + newline;
        end
    end

    % Assign non-externalized name-value pairs to variables matching the
    % name -- the function call depends on them. And this matches the
    % behavior of the externalized name-value pairs, which must be assigned
    % to a new variable after being deserialized.
    if any(groupIn & isLiteralIn)
        nvpIn = namesIn(groupIn & isLiteralIn);
        nvpIn = setdiff(nvpIn,origName);

        nvpParams = inParams(ismember([inParams.name],nvpIn));
        for n = 1:numel(nvpParams)
            code = code + indent + nvpParams(n).name + " = " + ...
                nvpParams(n).group + "." + nvpParams(n).name + ";" + newline;
        end
    end

    %
    % Function call
    %

    code = code + indent;
    % [ <outputs> ] = if there are any outputs
    if ~isempty(namesOut)
        code = code + "[" + strjoin(namesOut,",") + "] = ";
    end

    % Function name
    code = code + mf.Name;

    % (<inputs>) if there are any inputs. Name-value pairs added at the
    % end, as <optInVar>{:}. This name duplication depends on the
    % names not conflicting with the names of any required arguments. Which
    % the arguments-style declaration requires.
    if ~isempty(namesIn)
        namesIn = namesIn(~groupIn);
        argsIn = namesIn;

        % Add externalized optional inputs. They've been placed in a cell
        % array which is expanded into a comma-separated list.
        if any(~isLiteralIn & groupIn)
            argsIn = [argsIn, optInVar+"{:}"];
        end

        % Add non-external (local?) optional inputs. For these, we have
        % known defaults, which allowed their creation as local variables.
        % And that allows the <name>=<name> syntax used here. Must go last
        % because of the assignment syntax.
        if any(isLiteralIn & groupIn)
            argsIn = [ argsIn, arrayfun(@(nvp)nvp+"="+nvp,nvpIn)];
        end
        code = code + "(" + strjoin(argsIn,",") + ")";
    end
    code = code + ";" + newline;

    %
    % Serialize outputs
    %

    % Remove suffix from externalized names to obtain names used to capture
    % outputs from the function call.
    if ~isempty(externOut)
        origName = erase(externOut, MCPConstants.ExternalParamSuffix + ...
            textBoundary("end"));
    end

    % Serialize only those externalized outputs that were provided as
    % inputs in the external output optional input group. Not an error if
    % outputs are not provided.
    for n = 1:numel(externOut)
        % Check for non-zero length output location in output group.
        code = code + indent + ...
            "if strlength(" + externOutGroup + "." + externOut(n) + ") > 0" + newline;
        % Serialize individual output
        code = code + indent + indent + "serialize(" + mVar + ", " + ...
            externOutGroup + "." + externOut(n) + ...
           ", {" + origName(n) + "});" + newline;
        % Close the isfield check block
        code = code + indent + "end" + newline;
    end

    % And we're done
    code = code + "end" + newline;
end

function txt = assembleExternalizedDescription(param,io,ioMsg)
% Create a description for the externalized parameter named in param.

    import prodserver.mcp.MCPConstants
    refLoc = sprintf(MCPConstants.ReferenceSchemaLocationFormat,io,param);
    if startsWith(io,"input")
        prefix = MCPConstants.ReferenceSchemaInputPrefix;
    else
        prefix = MCPConstants.ReferenceSchemaOutputPrefix;
    end
    txt = [ioMsg;sprintf("%s %s",prefix,refLoc)];
    txt = strtrim(string(textwrap(txt,MCPConstants.WrapTextLen)));
end

function [indirect,tool] = externalizeParameters(tool,origIn,externIn,...
    origOut,externOut)
% Extract schema using original name, store using externalized name. If
% there are no externalized variables, indirect will be empty and tool will
% be unchanged.
    import prodserver.mcp.MCPConstants

    function d = externalizeDescription(d)
        import prodserver.mcp.internal.Constants
        % Remove the schema line, since it applies only to the data AT the
        % external location, not the URL itself (which is a string).
        schema = startsWith(d,Constants.Schema);
        if any(schema)
            d = d(~schema);
        end

        % Remove the wire-encoding message, since the URL is just a string,
        % which JSON can handle easily.
        encoding = contains(d,MCPConstants.WireEncodingResourceURI);
        if any(encoding)
            d = d(~encoding);
        end
    end

    indirect = [];
    for n = 1:numel(origIn)
        indirect.inputSchema.(externIn(n)) = tool.inputSchema.properties.(origIn(n));
        d = assembleExternalizedDescription(externIn(n), "inputSchema", ...
            MCPConstants.ByReferenceInMsg);
        % Add by-reference comment to description.
        dd = splitlines(tool.inputSchema.properties.(origIn(n)).description);
        dd = [dd; d];
        tool.inputSchema.properties.(origIn(n)).description = ...
            externalizeDescription(dd);
    end
    for n = 1:numel(origOut)
        indirect.outputSchema.(externOut(n)) = tool.outputSchema.properties.(origOut(n));
        d = assembleExternalizedDescription(externOut(n), "outputSchema",...
            MCPConstants.ByReferenceOutMsg);
        dd = splitlines(tool.outputSchema.properties.(origOut(n)).description);
        dd = [dd; d];
        tool.outputSchema.properties.(origOut(n)).description = ...
            externalizeDescription(dd);
    end   
end

function params = toolParameters(signature,schema)
% toolParameters Merge signature and description data into a single
% structure suitable for code generation. Produce an ordered struct array
% with one element per parameter, with fields:
%   name
%   kind
%   group
%   info
%   default
%   description

    if isfield(schema,"properties")
        toolParams = schema.properties;

        name = num2cell(signature.name);
        kind = num2cell(signature.kind);
        group = cellfun(@(n)signature.group.(n),name,UniformOutput=false);
        info = signature.validation;
        default = cellfun(@(n)signature.default.(n),name,UniformOutput=false);
        description = cellfun(@(n)toolParams.(n).description,name,...
            UniformOutput=false);
    
        % All non-arrayfun output to column vectors (arrayfun is known to
        % produce a column vector).
        name = name(:);
        kind = kind(:);
        info = info(:);
    
        params = struct("name", name, "kind", kind, "group", group, ...
            "info", info, "default", default, "description", description);
    else
        params = [];
    end
end

function code = argumentBlock(params,description,type,indent)
% argumentBlock Generate the code for an argument block

    % Don't generate empty argument blocks
    if isempty(params)
        code = ""; % Don't return empty, because empty is contagious.
        return; 
    end

    % argument(<type>)
    code = indent + "arguments(" + type + ")" + newline;
    for n = 1:numel(params)
        % Two lines for each parameter: descriptive comment followed by
        % variable name and validation.
        % <comment>
        % <indent> <variable name> <validation>
        %
        % The descriptive comment may span multiple lines.

        % Parentheses placed very strategically to trigger scalar
        % expansion. Don't move them unless you understood that.
        % description for each parameter stored with line breaks in order
        % to keep %#schema on its own line. 
        dd = splitlines(description(n).description);
        code = code + ...
            strjoin((indent + indent + "% ") + dd, newline) + ...
            newline;

        name = params(n);
        if strlength(description(n).group) > 0
            name = description(n).group + "." + name;
        end
        % User may not have specified anything about the type of the
        % argument.
        info = "";
        if isfield(description(n).info,"size")
            info = description(n).info.size;
        end
        if isfield(description(n).info,"type")
            info = [info, description(n).info.type]; %#ok<AGROW>
        end
        if isfield(description(n).info,"fcn")
            info = [info, description(n).info.fcn]; %#ok<AGROW>
        end
        
        default = "";
        if strlength(description(n).default) > 0 
            default = " = " + description(n).default;
        end
        code = code + indent + indent + name + " " + ...
            strjoin(info," ") + default + newline;
    end
    code = code + indent + "end" + newline;
end

function description = nonDuplicateArguments(description,renamed)
% renamed maps original names to new (unique) names: original -> unique.
% Move description(original) to description(unique) -- renamed may be
% empty. Note I said "move" -- this means delete description(original).
    name = keys(renamed);
    for n = 1:numel(name)
        rename = renamed(name(n));
        description(rename) = description(name(n));
        description = remove(description, name(n));
    end
end


function [isLiteral, names] = findLiterals(parameters,schema)
% findLiterals Search a matlab.metadata.Argument list to find all the
% elements with all dimensions fixed and prod(fixed dimensions) <=
% MaxLiteralLimit.
%
% Return parameter names and scalar classification.

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants
    import prodserver.mcp.jsonrpc.SchemaCallBy

    names = arrayfun(@(id)string(id.Name),[parameters.Identifier]);
    isLiteral = false(size(parameters));
    for n = 1:numel(parameters)
        p = parameters(n);
        if hasField(p,"Validation.Size") && ~isempty(p.Validation.Size)
            sz = 1;
            dims = p.Validation.Size;
            for k = 1:numel(dims)
                if isa(dims(k),"matlab.metadata.FixedDimension")
                    sz = sz * dims(k).Length;
                else
                    sz = Inf;
                end
            end
            % A parameter is a literal if the product of its dimensions is
            % less than MaxLiteralLimit. 
            isLiteral(n) = (sz <= MCPConstants.MaxLiteralSize);
        end

        %
        % The schema may confirm or countermand the call-by mode of the
        % parameter. 
        %

        % Parameter notation: x-call-by: value and x-call-by: reference
        % set the mode directly. No further processing: this is an
        % authoritative client directive that must be obeyed.
        if isfield(schema.properties.(p.Identifier.Name),SchemaCallBy.fieldName)
            isLiteral(n) = strcmpi(...
                schema.properties.(p.Identifier.Name).(SchemaCallBy.fieldName), ...
                SchemaCallBy.Value);
            continue;
        end

        if isLiteral(n) == false
            % Parameter size computed from the schema. Can only
            % realistically count the number of elements in the parameter
            % array. (Everything in MATLAB is an array, so all parameters
            % are arrays, even the degenerate ones that are scalars.)

            [~, maxSz] = prodserver.mcp.jsonrpc.countSchemaItems(...
                schema.properties.(p.Identifier.Name));

            % If the parameter size is <= MaxLiteralSize and the parameter
            % type is a known primitive (numeric, string, etc.) then the
            % parameter is a literal.

            isLiteral(n) = (maxSz <= MCPConstants.MaxLiteralSize );
        end
    end
end

function name = uniqueLocalVariable(in, out, local)
% uniqueLocalVariable Propose a local variable name. It will have an _<N>
% added if it conflicts with any of the names in the input or output
% parameter list.
    ki = string.empty; ko = ki;
    if ~isempty(in)
        ki = [in.name];
    end
    if ~isempty(out)
        ko = [out.name];
    end
    blacklist = [ ki, ko ];
    name = matlab.lang.makeUniqueStrings([blacklist, local]);
    name = name(end);
end