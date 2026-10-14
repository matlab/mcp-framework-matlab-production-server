function [result, httpCode, httpMsg, msgHeaders] = call(jrpc)
%call Handle MCP tools/call request. Resolves the named tool, assembles
%   positional, optional, and name-value arguments in order, invokes the
%   function, and encodes each output as structured content.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.jsonrpc.mcpEncode
    import prodserver.mcp.jsonrpc.mcpDecode

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;
    
    % Get tool definition
    svc = prodserver.mcp.handler.toolServices;
    d = svc.(MCPConstants.DefinitionVariable);

    % Find tool definition.
    tools = d.tools;

    % Cast to string because sometimes the name may be a char, which
    % don't count as uniform output.
    tName = cellfun(@(t)string(t.name),tools);

    % params.name identifies the tool and is required by the tools/call
    % schema. Without it there is nothing to look up.
    if ~hasField(jrpc,"params.name")
        error("prodserver:mcp:MissingParams", ...
            "tools/call request lacks the required params.name.");
    end

    fcn = jrpc.params.name;
    k = strcmp(tName,fcn);
    if nnz(k) > 1
        error("prodserver:mcp:AmbiguousToolName", ...
            "Multiple tools matching name '%s'. Rebuild server " + ...
            "using unambigous names.", fcn);
    end
    if nnz(k) == 0
        error("prodserver:mcp:ToolUnavailable", ...
            "Tool '%s' not available on this MCP server.", fcn);
    end

    % Only one definition matching the tool name.
    t = tools{k};

    % Record number of times each tool is called
    toolCallMetric = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
        fcn + prodserver.mcp.MCPConstants.MCPToolCallSuffix;
    prodserver.metrics.incrementCounter(toolCallMetric,1)

    % JRPC in MCP does not define argument order. So we (cleverly!)
    % insert order information into the definition. Assemble a cell
    % array with the arguments in the right order.
    sig = d.signatures;

    % Determine wire encoding for this tool.
    toolEncoding = prodserver.mcp.jsonrpc.toolEncoding(fcn,sig=sig);

    % arguments is optional in the tools/call schema: a tool that takes no
    % inputs is called without it. Treat an absent or empty arguments object
    % as no arguments supplied rather than failing to index it.
    if hasField(jrpc,"params.arguments") && isstruct(jrpc.params.arguments)
        actual = string(fieldnames(jrpc.params.arguments));
    else
        actual = string.empty(0,1);
        jrpc.params.arguments = struct();
    end

    % Wire-decode input arguments using the tool's encoding.
    allVals = cell(1,numel(actual));
    for i = 1:numel(actual)
        allVals{i} = jrpc.params.arguments.(actual(i));
    end
    decoded = mcpDecode(toolEncoding, allVals{:});
    for i = 1:numel(actual)
        jrpc.params.arguments.(actual(i)) = decoded{i};
    end

    % Separate optional from required arguments.
    %  1. Subtract required from all positional to yield max. optional.
    %  2. Keep optional that appear in the tools/call body.
    % A tool with no required inputs may advertise "required" either way: the
    % key can be absent entirely, or present and empty. Both shapes are real --
    % Test/tools/toyTools/toyZeroInputs.json omits it, while a live server
    % serving that same tool returns "required":[] -- so neither the field nor
    % its contents can be assumed. Hence the guard, and hence string() rather
    % than split() just below: jsondecode turns "required":[] into a 0x0 double,
    % which string() tolerates and split() rejects with
    % MATLAB:string:MustBeCharCellArrayOrString. That exact mismatch crashed the
    % client side in +jsonrpc/toolsCall.m.
    if isfield(t.inputSchema,"required")
        in = string(t.inputSchema.required);
    else
        in = string.empty(0,1);
    end
    kind = ParameterKind(sig.(fcn).input.kind);
    optional = sig.(fcn).input.order(kind == ParameterKind.Optional);
    optional = intersect(optional, actual, "stable");
    nvp = setdiff(actual,[in(:); optional(:)]);

    % EVERY required argument must be present. Testing that the intersection
    % is non-empty would only catch the case where all of them are missing,
    % and a partially-supplied call would then fail on an indexing error
    % below -- reported as an internal fault rather than bad params.
    missing = setdiff(in, actual, "stable");
    if ~isempty(missing)
        error("prodserver:mcp:BadInputArguments", ...
            "Tool '%s' requires inputs '%s', but received '%s'. " + ...
            "Missing: '%s'.", ...
            fcn, strjoin(in,","), strjoin(actual,","), strjoin(missing,","));
    end

    % Make space for all arguments.
    N = numel(in) + numel(optional) + (numel(nvp) * 2);
    inArgs = cell(1,N);

    % Fill positionally: required first, then optional positional, then
    % name-value pairs at the end. One cursor runs across all three loops.
    %
    % The cursor is deliberately independent of any loop variable. Reusing the
    % required-argument loop variable, and guarding the optional and
    % name-value loops behind it, breaks for a tool with no required inputs:
    % MATLAB assigns the loop variable the empty range when a loop does not
    % run, so the guard is never satisfied and every supplied argument is
    % silently dropped.
    n = 1;
    for k = 1:numel(in)
        inArgs{n} = jrpc.params.arguments.(in{k});
        n = n + 1;
    end

    % Optional positional arguments. Already narrowed to those the call
    % actually supplied.
    for k = 1:numel(optional)
        inArgs{n} = jrpc.params.arguments.(optional(k));
        n = n + 1;
    end

    % TODO: Repeated arguments.

    % Add name-value pairs to the end of the argument list: use
    % name of the argument as the name of the name-value pair.
    for k = 1:numel(nvp)
        inArgs{n} = nvp(k);
        inArgs{n+1} = jrpc.params.arguments.(nvp(k));
        n = n + 2;
    end

    % Create a cell array large enough for all the outputs. 
    out = sig.(fcn).output.name;
    outArgs = cell(1,numel(out));

    % Call the tool and encode its outputs. A failure anywhere below is a
    % tool-EXECUTION error (the tool ran and failed). MCP represents that as
    % an isError result carried over HTTP 200 -- NOT as a JSON-RPC protocol
    % error. Protocol-level errors (unknown method, bad/missing params) are
    % raised before this point and formatted by the top-level handler.
    %
    % Call through a function handle, not feval. An arguments block that
    % rejects an input inside feval counts the function name as argument 1,
    % so the error names the wrong position, and that text is what the
    % client, often an LLM, reads to correct its call.
    %
    % str2func does not check that the function exists, so a definition
    % naming a missing function fails when the handle is called, inside the
    % try, and is reported as isError just as it was under feval.
    tool = str2func(sig.(fcn).function);
    try
        [outArgs{:}] = tool(inArgs{:});

        % Content must have a value to be wire-encoded.
        content = []; %#ok<NASGU>

        % Extract tool results from cell array and write them to structure
        % (which will be JSON-encoded). outArgs and out define the order,
        % which structuredContent does not care about.
        encodedOut = mcpEncode(toolEncoding, outArgs{:});
        for n = 1:numel(out)
            r.structuredContent.(out{n}) = encodedOut{n};
        end

        % Add by-reference outputs to content and structuredContent array so
        % LLMs don't mistakenly assume the call failed because r.content is
        % empty. (A function with all large outputs may have all of its
        % outputs passed by reference.)

        % Find external outputs: look for t.inputSchema.properties objects
        % with writeOnly: true.
        if hasField(t,"inputSchema.properties")
            % Named props, not in: in holds the required-argument list, and
            % overwriting it here left the two meanings of one variable only a
            % few lines apart.
            props = fieldnames(t.inputSchema.properties);
            for p = 1:numel(props)
                if hasField(t.inputSchema.properties.(props{p}),"writeOnly") && ...
                    t.inputSchema.properties.(props{p}).writeOnly == true
                    if isfield(jrpc.params.arguments,props{p})
                        r.structuredContent.(props{p}) = ...
                            jrpc.params.arguments.(props{p});
                    end
                end
            end
        end

        % Return content as a string. Should not be required but some clients
        % require non-empty content, even when structuredContent has a value
        % (looking at you, Claude).
        %
        % Encode to JSON. Gets encoded again later, which allows it to
        % be delivered to the client as a legitimate JSON string. Which
        % is what Claude wants...
        c.type = "text";
        if isfield(r, 'structuredContent')
            c.text = jsonencode(r.structuredContent);
        else
            c.text = "{}";
        end
        r.content = {c} ;  % Must be array for Claude desktop.
    catch me
        % Tool-execution error. Report via the MCP isError convention
        % (follow it or these errors will be ignored); HTTP status stays
        % 200 because the transport and the protocol both succeeded.
        r = struct();
        r.isError = true;
        tc.type = "text";
        if ~isempty(me.stack)
            location = me.stack(1);
            [~, efile] = fileparts(location.file);
            tc.text = sprintf("%s:%d : %s", efile, location.line, me.message);
        else
            tc.text = me.message;
        end
        r.content = {tc};
    end
    result.result = r;
end
