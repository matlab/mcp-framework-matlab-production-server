function code = mcpWrapper(fcn,tool,opts)
%mcpWrapper Generate a wrapper named tool from the function in fcn. Return
%wrapper function code as a string.

% Copyright 2025, The MathWorks, Inc.

    % All inputs pre-validated by caller. arguments block used instead of
    % inputParser for convenience and readability.
    arguments
        fcn 
        tool 
        % Names of variables with explicit importers. 
        opts.import string = string.empty
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

    % Determine which inputs and outputs are scalars. Require argument
    % block entries for all inputs and outputs.

    [isScalarIn, namesIn] = findScalars(mf.Signature.Inputs);
    [isScalarOut, namesOut] = findScalars(mf.Signature.Outputs);

    % Inputs and outputs are easier to manage if they have unique names.
    % URL-based outputs are moved to the input argument list. And that
    % only works if all the names are unique.
    nIn = numel(namesIn);
    uniqArgs = matlab.lang.makeUniqueStrings([namesIn, namesOut]);

    renamedIn = find(strcmp(namesIn,uniqArgs(1:nIn)) == 0);
    renamedIn = dictionary(namesIn(renamedIn),uniqArgs(renamedIn));
    namesIn(:) = uniqArgs(1:nIn);

    renamedOut = find(strcmp(namesOut,uniqArgs(nIn+1:end)) == 0)+nIn;
    renamedOut = dictionary(namesOut(renamedOut-nIn),uniqArgs(renamedOut));
    namesOut(:) = uniqArgs(nIn+1:end);

    % Form output parameter list from names of all scalar outputs.
    scalarOut = namesOut(isScalarOut);
    outParamList = "";
    if ~isempty(scalarOut)
        outParamList = "[" + strjoin(scalarOut,",") + "] = ";
    end

    % Form list of externalized output parameters.
    externOut = setdiff(namesOut,scalarOut,'stable');
    externOutList = string.empty;
    if ~isempty(externOut)
        externOut = externOut + MCPConstants.ExternalParamSuffix;
        externOutList = strjoin(externOut, ",");
    end
    
    % Add external suffix to externalized input parameters
    externIn = namesIn(~isScalarIn) + MCPConstants.ExternalParamSuffix;

    % Get argument block information from the file. These two dictionaries
    % map the ORIGINAL argument name to description and validation. They
    % also indicate argument group membership, which identifies name-value
    % pair arguments.
    [inDescription, outDescription] = parameterDescription(mf); 

    % Form input parameter list from original input names and any
    % externalized output parameters. For input arguments that belong to a
    % group, only add the group to the parameter list. (And put the group
    % name at the end of the list.)

    inParamList = namesIn; 
    inParamList(~isScalarIn) = externIn;

    groupList = string.empty;
    groupIn = arrayfun(@(n)hasField(inDescription(n),"group"),namesIn);
    if any(groupIn)
        grouped = lookup(inDescription,namesIn(groupIn));
        groupList = unique([ grouped.group ],"stable");
        inParamList = inParamList(~groupIn);
    end

    inParamList = [ inParamList, externOutList, groupList ];

    if ~isempty(inParamList)
        inParamList = "(" + strjoin(inParamList,",") + ")";
    end

    indent = "    ";

    % Function line!
    code = "function " + outParamList + tool + inParamList + newline;

    %
    % Description
    %
    comment = string(mf.Description);
    if ~isempty(mf.DetailedDescription)
        dd = string(split(mf.DetailedDescription,newline));
        comment = [comment; dd];
    end
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

    % Map descriptions to the deduplicated names of the arguments.
    inDescription = nonDuplicateArguments(inDescription,renamedIn);
    outDescription = nonDuplicateArguments(outDescription,renamedOut);

    % Reorganize to reflect externalization -- externalized inputs have new
    % names, externalized outputs have new name AND move to inputs. All
    % externalized arguments validate as scalar strings.

    % Change names of all externalized inputs -- including optional inputs.
    for n = 1:numel(namesIn)
        if isScalarIn(n) == false
            value = inDescription(namesIn(n));
            validation =  "(1,1) string";  % All URLs are strings
            % Grouped parameters are optional, so the must have a default
            % value. Since externalized parameters are strings, "" is an
            % appropriate default value.
            if isfield(value,"group") 
                validation = validation + " = """"";
            end
            value.validation = validation;
            
            inDescription(namesIn(n)+MCPConstants.ExternalParamSuffix) = value;
            inDescription = remove(inDescription,namesIn(n)); 
        end
    end

    % If the function has no inputs and one or more externalized outputs,
    % creates an input dictionary to receive the externalized outputs.
    if isempty(inDescription) && ~isempty(externOut)
        inDescription = configureDictionary("string","struct");
    end

    % Move all externalized outputs to the input argument block, renaming
    % them in the process.
    for n = 1:numel(namesOut)
        if isScalarOut(n) == false
            value = outDescription(namesOut(n));
            % Changing the data type from ?? to external sink, which is a
            % URL, which is a scalar string.
            value.validation = "(1,1) string";
            inDescription(namesOut(n)+MCPConstants.ExternalParamSuffix) = value;
            outDescription(namesOut(n)) = [];
        end
    end

    % Form the input argument list for the wrapper function: all inputs
    % (externalized and untouched) followed by all externalized outputs and
    % then by name-value pairs. 
    wrapIn = namesIn;
    wrapIn(~isScalarIn) = externIn;
    nvpIn = string.empty;
    if any(groupIn)
        nvpIn = wrapIn(groupIn);
        wrapIn = wrapIn(~groupIn);
    end
    code = code + argumentBlock([wrapIn, externOut, nvpIn],inDescription,...
        "Input",indent);

    % Form the output argument list for the wrapper function: only
    % non-externalized (untouched) outputs.
    wrapOut = namesOut(isScalarOut);
    code = code + argumentBlock(wrapOut,outDescription,...
        "Output",indent);

    % Declare marshaller if any externalized inputs or outputs
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
            defVar = uniqueLocalVariable(inDescription, ...
                outDescription, defVar);
            importVar = uniqueLocalVariable(inDescription, ...
                outDescription, importVar);

            code = code + indent + defVar + " = matfile(""" + ...
                MCPConstants.DefinitionFile + """);" + newline;
            code = code + indent + importVar + " = " + defVar + "." + ...
                MCPConstants.ImporterVariable + ";" + newline;
        end

        % ~isScalarIn identifies the externalized inputs. groupIn
        % identifies the "grouped" optional inputs. If the intersection is
        % non-empty, there's extra work to do.
        if any(~isScalarIn & groupIn)
            % Externalized optional inputs are passed to the original
            % function as name-value pairs. Because we don't know how many
            % there might be, declare a cell array here to populate with
            % any that are actually provided.
            optInVar = uniqueLocalVariable(inDescription, ...
                outDescription, optInVar);
            optInVar = optInVar(end);
            code = code + indent + optInVar + " = {};" + newline;
        end
    end
    for n = 1:numel(externIn)
        % Deserialize and unwrap -- deserialize always returns a cell
        % array.
        d = inDescription(externIn(n));

        importThisVar = "";
        if ismember(origName(n),opts.import)
            % Additional argument to deserialize. Don't forget the
            % comma. Fetch the importer from the import structured
            % loaded from the tool definition file.
            importThisVar = ", import=" + importVar + "." + origName(n);

        end

        if isfield(d,"group")
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
                mVar + "," + externIn(n) + importThisVar + ");" + newline;
            code = code + indent + origName(n) + " = " + origName(n) + ...
                "{1};" + newline;
        end
    end

    % Assign non-externalized name-value pairs to variables matching the
    % name -- the function call depends on them. And this matches the
    % behavior of the externalized name-value pairs, which must be assigned
    % to a new variable after being deserialized.
    if any(groupIn & isScalarIn)
        nvpIn = namesIn(groupIn & isScalarIn);
        nvpIn = setdiff(nvpIn,origName);
        for n = 1:numel(nvpIn)
            grp = inDescription(nvpIn(n)).group;
            code = code + indent + nvpIn(n) + " = " + grp + "." + ...
                nvpIn(n) + ";" + newline;
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
        if any(~isScalarIn & groupIn)
            argsIn = [argsIn, optInVar+"{:}"];
        end

        % Add non-external (local?) optional inputs. For these, we have
        % known defaults, which allowed their creation as local variables.
        % And that allows the <name>=<name> syntax used here. Must go last
        % because of the assignment syntax.
        if any(isScalarIn & groupIn)
            argsIn = [ argsIn, arrayfun(@(nvp)nvp+"="+nvp,nvpIn)];
        end
        code = code + "(" + strjoin(argsIn,",") + ")";
    end
    code = code + ";" + newline;

    %
    % Serialize outputs
    %
    if ~isempty(externOut)
        origName = erase(externOut, MCPConstants.ExternalParamSuffix + ...
            textBoundary("end"));
    end
    for n = 1:numel(externOut)
        code = code + indent + "serialize(" + mVar + ", " + externOut(n) + ...
           ", {" + origName(n) + "});" + newline;
    end

    % And we're done
    code = code + "end" + newline;
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
        p = params(n);

        % Parentheses placed very strategically to trigger scalar
        % expansion. Don't move them unless you understood that.
        code = code + ...
            strjoin((indent + indent + "% ") + ...
                description(p).description, newline) + ...
            newline;

        name = p;
        if isfield(description(p),"group")
            name = description(p).group + "." + name;
        end
        code = code + indent + indent + name + " " + ...
            description(p).validation + newline;
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


function [isScalar, names] = findScalars(parameters)
% findScalars Search a matlab.metadata.Argument list to find all the
% elements with all dimensions fixed and prod(fixed dimensions) == 1.
% Return parameter names and scalar classification.
    import prodserver.mcp.internal.hasField

    names = arrayfun(@(id)string(id.Name),[parameters.Identifier]);
    isScalar = false(size(parameters));
    for n = 1:numel(parameters)
        p = parameters(n);
        if hasField(p,"Validation.Size") && ~isempty(p.Validation.Size)
            sz = 1;
            dims = p.Validation.Size;
            for k = 1:numel(dims)
                if isa(dims(k),"matlab.metadata.FixedDimension")
                    sz = sz * dims(k).Length;
                else
                    sz = 0;
                end
            end
            % A variable is a scalar if the product of its dimensions is 1.
            isScalar(n) = (sz == 1);
        end
    end
end

function name = uniqueLocalVariable(in, out, local)
% uniqueLocalVariable Propose a local variable name. It will have an _<N>
% added if it conflicts with any of the names in the input or output
% parameter list.
    ki = string.empty; ko = ki;
    if ~isempty(in)
        ki = keys(in);
    end
    if ~isempty(out)
        ko = keys(out);
    end
    blacklist = [ ki; ko ];
    name = matlab.lang.makeUniqueStrings([blacklist; local]);
    name = name(end);
end