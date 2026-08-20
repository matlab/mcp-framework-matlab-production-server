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

    actual = string(fieldnames(jrpc.params.arguments));

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
    in = string(t.inputSchema.required);
    kind = ParameterKind(sig.(fcn).input.kind);
    optional = sig.(fcn).input.order(kind == ParameterKind.Optional);
    optional = intersect(optional, actual, "stable");
    nvp = setdiff(actual,[in; optional]);

    % All required arguments must be present.
    if isempty(intersect(in,actual))
        error("prodserver:mcp:BadInputArguments", ...
            "Tool '%s' requires inputs '%s', but received '%s'.", ...
            fcn,strjoin(t.inputSchema.required,","), strjoin(in,","));
    end

    % Make space for all arguments.
    N = numel(in) + numel(optional) + (numel(nvp) * 2);
    inArgs = cell(1,N);

    % Required arguments.
    for n = 1:numel(in)
        inArgs{n} = jrpc.params.arguments.(in{n});
    end

    % n is the index of the last required argument.
    if n < numel(actual)
        n = n + 1;

        % Optional positional arguments.
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
    end

    % Create a cell array large enough for all the outputs. 
    out = sig.(fcn).output.name;
    outArgs = cell(1,numel(out));

    % Call the tool.
    [outArgs{:}] = feval(sig.(fcn).function, inArgs{:});

    % Content must have a value to be wire-encoded.
    content = [];

    % Extract tool results from cell array and write them to structure
    % (which will be JSON-encoded). outArgs and out define the order,
    % which structuredContent does not care about.
    encodedOut = mcpEncode(toolEncoding, outArgs{:});
    for n = 1:numel(out)
        r.structuredContent.(out{n}) = encodedOut{n};

        % Should not be required but some clients require non-empty
        % content, even when structuredContent has a value (looking at
        % you, Claude).
        %
        % Encode to JSON. Gets encoded again later, which allows it to
        % be delivered to the client as a legitimate JSON string. Which
        % is what Claude wants...
        %content.(out{n}) = outArgs{n};
    end

    % Add by-reference outputs to content and structuredContent array so 
    % LLMs don't mistakenly assume the call failed because r.content is 
    % empty. (A function with all large outputs may have all of its 
    % outputs passed by reference.) 

    % Find external outputs: look for t.inputSchema.properties objects
    % with writeOnly: true.
    if hasField(t,"inputSchema.properties")
        in = fieldnames(t.inputSchema.properties);
        for n = 1:numel(in)
            if hasField(t.inputSchema.properties.(in{n}),"writeOnly") && ...
                t.inputSchema.properties.(in{n}).writeOnly == true
                if isfield(jrpc.params.arguments,in{n})
                    %content.(in{n}) = jrpc.params.arguments.(in{n});
                    r.structuredContent.(in{n}) = jrpc.params.arguments.(in{n});
                end
            end
        end
    end

    % Return content as a string. 
    c.type = "text";
    %c.text = jsonencode(mcpEncode(toolEncoding,content));
    c.text = jsonencode(r.structuredContent);
    r.content = {c} ;  % Must be array for Claude desktop.
    result.result = r;
end
