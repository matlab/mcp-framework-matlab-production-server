function [result, httpCode, httpMsg, msgHeaders] = call(jrpc, version)
%call Handle MCP tools/call request. Resolves the named tool, assembles
%   positional, optional, and name-value arguments in order, invokes the
%   function, and encodes each output as structured content.
%
%   VERSION is the protocol revision serving the request. It decides how
%   invalid arguments are reported and names the per-revision metrics; the
%   rest of the tool contract is revision-independent, which is why there is
%   one call.m and not one per adapter.

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

    % A tools/call with no 'name' is a malformed request, not a server
    % fault: without this guard the field access below raises a raw MATLAB
    % error that maps to -32603/500.
    if ~hasField(jrpc, 'params.name')
        error("prodserver:mcp:InvalidParams", ...
            "tools/call requires a 'name' parameter naming the tool to invoke.");
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

    % Each call to a known tool is counted exactly once: as a call
    % (MCP_<tool>_Call) when the tool is invoked, or as a rejection
    % (MCP_<tool>_Rejected) when the server refuses it first. Each is broken
    % out by protocol revision too. VERSION is the revision actually serving
    % the request, handed down by the dispatcher, so this names no revision
    % and needs no default.
    %
    % Re-deriving it from the body instead gets the wrong answer whenever an
    % alias is in play: a _meta declaring 2024-11-05 resolves to the
    % 2025-06-18 adapter, and reading the body would file the call under a
    % bucket supportedVersions() does not contain.
    stem = prodserver.mcp.MCPConstants.MCPMetricPrefix + fcn;
    revision = "_" + replace(version, "-", "_");
    callMetric = stem + prodserver.mcp.MCPConstants.MCPToolCallSuffix;
    rejectedMetric = stem + prodserver.mcp.MCPConstants.MCPToolRejectedSuffix;

    % JRPC in MCP does not define argument order. So we (cleverly!)
    % insert order information into the definition. Assemble a cell
    % array with the arguments in the right order.
    sig = d.signatures;

    % Determine wire encoding for this tool.
    toolEncoding = prodserver.mcp.jsonrpc.toolEncoding(fcn,sig=sig,def=t);

    % The tool's required inputs, in order. A tool with no required inputs
    % has no 'required' member at all -- defineForMCP emits a bare
    % {"type":"object"} schema -- and that must give an empty list, not a
    % field-access error that turns a legal zero-argument call into
    % -32603/500.
    in = prodserver.mcp.internal.requiredNames(t, "inputSchema");

    % The identifier of every invalid-argument error, under 2025-06-18.
    badArguments = "prodserver:mcp:InvalidParams:arguments";

    % Arguments that fail validation -- none where some are required, an
    % unknown name, a missing required one, a value the schema rejects -- are
    % reported the way the serving revision says: 2026-07-28 as a tool
    % execution error the model can read and correct, 2025-06-18 as -32602.
    % Either way the tool never runs, and the arguments are checked before
    % wire decoding: decoding a JSON string turns it into a char, which
    % MATLAB will treat as character codes wherever it expects a number.
    toolErrors = prodserver.mcp.protocol.inputErrorsAreToolErrors(version);

    % 'arguments' must be a JSON object. A JSON array of objects decodes to a
    % struct array, which would otherwise fail the per-argument checks below
    % with a raw MATLAB error, -32603/500. Only null counts as absent; but
    % jsondecode gives null and an empty array alike as [], so [] can't be
    % told from null here.
    isNull = @(a) isnumeric(a) && isempty(a);
    if hasField(jrpc, 'params.arguments') && ...
            ~isNull(jrpc.params.arguments) && ...
            ~(isstruct(jrpc.params.arguments) && isscalar(jrpc.params.arguments))
        result = rejectArguments(result, toolErrors, ...
            rejectedMetric, revision, ...
            "prodserver:mcp:InvalidParams", sprintf( ...
            "The 'arguments' of a call to tool '%s' must be a JSON object.", fcn));
        return
    end

    % A call may legitimately omit 'arguments' (or send null) only when the
    % tool declares no required inputs. It must not reach the raw
    % fieldnames() access -- that raises an untyped MATLAB error and maps to
    % -32603/500.
    if ~hasField(jrpc, 'params.arguments') || ~isstruct(jrpc.params.arguments)
        if ~isempty(in)
            result = rejectArguments(result, toolErrors, ...
                rejectedMetric, revision, ...
                "prodserver:mcp:InvalidParams", sprintf( ...
                "Tool '%s' requires inputs '%s', but the call carried no " + ...
                "'arguments' object.", fcn, strjoin(in, ",")));
            return
        end
        jrpc.params.arguments = struct();
    end

    actual = string(fieldnames(jrpc.params.arguments));

    % Every required argument must be present (XD12). An empty IN requires
    % nothing, so leaves nothing missing.
    missing = setdiff(in, actual, "stable");
    if ~isempty(missing)
        result = rejectArguments(result, toolErrors, ...
            rejectedMetric, revision, ...
            "prodserver:mcp:BadInputArguments", sprintf( ...
            "Tool '%s' requires inputs '%s', but received '%s'. Missing: '%s'.", ...
            fcn, strjoin(in, ","), strjoin(actual, ","), strjoin(missing, ",")));
        return
    end

    % Every argument must be an input of the tool, with a value its schema
    % allows.
    badValue = prodserver.mcp.validation.toolArgumentError(t, ...
        jrpc.params.arguments, toolEncoding);
    if strlength(badValue) > 0
        result = rejectArguments(result, toolErrors, ...
            rejectedMetric, revision, ...
            badArguments, badValue);
        return
    end

    % Plain JSON carries datetimes as ISO 8601 text and durations as
    % seconds; the schema says which values those are. The invertible
    % encoding has its own forms, which wire decoding handles.
    if toolEncoding == prodserver.mcp.WireEncoding.JSON
        try
            [jrpc.params.arguments, badValue] = ...
                prodserver.mcp.jsonrpc.decodeJSONValues(t.inputSchema, ...
                    jrpc.params.arguments, "Argument");
        catch decodeErr
            % As for wire decoding below: arguments that can't be converted
            % are invalid input, never an internal error.
            badValue = decodeErr.message;
        end
        if strlength(badValue) > 0
            result = rejectArguments(result, toolErrors, ...
                rejectedMetric, revision, ...
                badArguments, badValue);
            return
        end
    end

    % Wire-decode input arguments using the tool's encoding.
    allVals = cell(1,numel(actual));
    for i = 1:numel(actual)
        allVals{i} = jrpc.params.arguments.(actual(i));
    end
    try
        decoded = mcpDecode(toolEncoding, allVals{:});
    catch decodeErr
        % Arguments that can't be decoded are invalid input, like any other.
        result = rejectArguments(result, toolErrors, ...
            rejectedMetric, revision, ...
            badArguments, decodeErr.message);
        return
    end
    for i = 1:numel(actual)
        jrpc.params.arguments.(actual(i)) = decoded{i};
    end

    % Separate optional from required arguments.
    %  1. Subtract required from all positional to yield max. optional.
    %  2. Keep optional that appear in the tools/call body.
    %
    % A signature built by observing example calls (build's example= path,
    % through SchemaObserver) has no 'input' member at all for a tool that
    % takes no inputs, so every call to it failed with -32603/500 once
    % deployed (ND12). In-process tests build signatures with defineForMCP,
    % which always writes an empty 'input', and could not see it.
    optional = string.empty;
    if hasField(sig, fcn + ".input.kind")
        kind = ParameterKind(sig.(fcn).input.kind);
        optional = string(sig.(fcn).input.order(kind == ParameterKind.Optional));
    end
    optional = intersect(optional, actual, "stable");
    nvp = setdiff(actual,[in(:); optional(:)]);

    % Make space for all arguments.
    N = numel(in) + numel(optional) + (numel(nvp) * 2);
    inArgs = cell(1,N);

    % Required arguments. Every field read here is one the check above has
    % just proved present, so none of these accesses can fail.
    for k = 1:numel(in)
        inArgs{k} = jrpc.params.arguments.(in(k));
    end

    % n is the index of the last required argument. Assigned explicitly
    % rather than inherited from the loop variable above, which is left
    % unspecified when the range is empty -- as it is for a tool that
    % requires no inputs.
    n = numel(in);
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

    % Create a cell array large enough for all the outputs. 'output' is
    % absent for a tool with no outputs, for the same reason as 'input'.
    % Read through sig.(fcn) so a tool with no signature entry at all still
    % fails here, as the internal error it is.
    out = {};
    if isfield(sig.(fcn), "output") && isfield(sig.(fcn).output, "name")
        out = cellstr(sig.(fcn).output.name);
    end
    outArgs = cell(1,numel(out));

    % Call the tool and shape its output. A failure anywhere once the tool
    % is invoked is a tool-execution error: the tool ran and rejected its
    % input (or failed internally). MCP reports this in-band as an isError
    % content block over HTTP 200 -- not as a protocol-level JSON-RPC error
    % -- so the model sees the message and can correct the call. Problems
    % found before this point are handled there: an unknown tool is a
    % protocol error, and invalid arguments are reported as rejectArguments
    % says.
    %
    % Call through a handle, never feval. When an arguments block rejects an
    % input inside feval, MATLAB can count the function name as argument 1,
    % so every "Invalid argument at position N" the model reads is one too
    % high (D36). Whether it does depends on how THIS function was reached:
    % ProtocolDispatcher's own feval happens to mask the miscount, a direct or
    % handle call exposes it. A handle counts correctly in every context.
    % str2func does not check that the function exists, so a missing tool
    % still fails at the call, inside the try, exactly as feval did.
    tool = str2func(sig.(fcn).function);

    % The tool is about to be invoked: this is a call, whether or not the
    % tool then raises an error.
    countMetric(callMetric, revision);
    try
        % Call the tool.
        [outArgs{:}] = tool(inArgs{:});

        % Content must have a value to be wire-encoded.
        content = [];

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
            in = fieldnames(t.inputSchema.properties);
            for n = 1:numel(in)
                if hasField(t.inputSchema.properties.(in{n}),"writeOnly") && ...
                    t.inputSchema.properties.(in{n}).writeOnly == true
                    if hasField(jrpc, "params.arguments." + string(in{n}))
                        r.structuredContent.(in{n}) = jrpc.params.arguments.(in{n});
                    end
                end
            end
        end

        % Return content as a string. Should not be required, but some
        % clients require non-empty content even when structuredContent
        % has a value.
        %
        % Encode to JSON. Gets encoded again later, which delivers it to
        % the client as a legitimate JSON string, as those clients expect.
        c.type = "text";
        if isfield(r, 'structuredContent')
            c.text = jsonencode(r.structuredContent);
        else
            c.text = "{}";
        end
        r.content = {c} ;  % Must be array for Claude desktop.
        result.result = r;
    catch toolErr
        % Tool-execution failure: surface the tool's message as an isError
        % content block (HTTP 200 is left in place), discarding any partial
        % output so the result is a clean error for the model to act on.
        %
        % The message only, deliberately without the "file:line : " prefix
        % that 1.5 added and that protocol errors still carry. The reader is
        % the model, which can act on the message but not on a location;
        % stack(1) need not be the tool's own code; and the prefix discloses
        % deployed file names and line numbers to every client.
        result.result = toolError(toolErr.message);
    end
end

function result = rejectArguments(result, toolErrors, metric, revision, id, msg)
% Reject a call's arguments without running the tool, counting the
% rejection in METRIC. As a tool execution error -- isError, the message in
% content, HTTP 200 -- if toolErrors; otherwise by raising ID, which the
% protocol maps to -32602.
    countMetric(metric, revision);
    if toolErrors
        result.result = toolError("Input validation error: " + msg);
    else
        error(id, "%s", msg);
    end
end

function r = toolError(text)
% A tool execution error: isError, and TEXT for the model to act on.
    r.isError = true;
    r.content = {struct('type', "text", 'text', text)};  % An array, for Claude desktop
end

function countMetric(metric, revision)
% Count once in METRIC and once in its per-revision breakdown.
    prodserver.metrics.incrementCounter(metric, 1);
    prodserver.metrics.incrementCounter(metric + revision, 1);
end
