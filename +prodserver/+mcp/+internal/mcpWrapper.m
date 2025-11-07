function code = mcpWrapper(fcn,tool)
%mcpWrapper Generate a wrapper named tool from the function in fcn. Return
%wrapper function code as a string.

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
    externOutList = "";
    if ~isempty(externOut)
        externOut = externOut + MCPConstants.ExternalParamSuffix;
        externOutList = strjoin(externOut, ",");
    end
    
    % Add external suffix to externalized input parameters
    externIn = namesIn(~isScalarIn) + MCPConstants.ExternalParamSuffix;

    % Form input parameter list from original input names and any
    % externalized output parameters.
    inParamList = namesIn; 
    inParamList(~isScalarIn) = externIn;
    inParamList = [ inParamList, externOutList ];

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

    % Get argument block information from the file. These two dictionaries
    % map the ORIGINAL argument name to description and validation. 
    [inDescription, outDescription] = parameterDescription(mf);

    % Map descriptions to the deduplicated names of the arguments.
    inDescription = nonDuplicateArguments(inDescription,renamedIn);
    outDescription = nonDuplicateArguments(outDescription,renamedOut);

    % Reorganize to reflect externalization -- externalized inputs have new
    % names, externalized outputs have new name AND move to inputs. All
    % externalized arguments validate as scalar strings.

    % Change names of all externalized inputs.
    for n = 1:numel(namesIn)
        if isScalarIn(n) == false
            value = inDescription(namesIn(n));
            value.validation = "(1,1) string";  % All URLs are strings
            inDescription(namesIn(n)+MCPConstants.ExternalParamSuffix) = value;
            inDescription = remove(inDescription,namesIn(n)); 
        end
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
    % (externalized and untouched) followed by all externalized outputs.
    wrapIn = namesIn;
    wrapIn(~isScalarIn) = externIn;
    code = code + argumentBlock([wrapIn, externOut],inDescription,...
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

    origName = erase(externIn, MCPConstants.ExternalParamSuffix + ...
        textBoundary("end"));
    code = code + indent + "% deserialize always returns a cell array." + ...
        newline;
    for n = 1:numel(externIn)
        % Deserialize and unwrap -- deserialize always returns a cell
        % array.
        code = code + indent + origName(n) + " = deserialize(" + ...
            mVar + "," + externIn(n) + ");" + newline;
        code = code + indent + origName(n) + " = " + origName(n) + ...
            "{1};" + newline;
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

    % (<inputs>) if there are any inputs
    if ~isempty(namesIn)
        code = code + "(" + strjoin(namesIn,",") + ")";
    end
    code = code + ";" + newline;

    %
    % Serialize outputs
    %
    origName = erase(externOut, MCPConstants.ExternalParamSuffix + ...
        textBoundary("end"));
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

        code = code + indent + indent + p + " " + ...
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
