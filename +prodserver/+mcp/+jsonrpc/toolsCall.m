function body = toolsCall(tool,id,def,sig,varargin)
%toolsCall Create structure for JSONRPC MCP tools/call body.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.internal.hasField

    body.id = id;
    body.method = "tools/call";
    body.jsonrpc = MCPConstants.jrpcVersion;
    body.params.name = tool;

    % The same encoding the client decodes the outputs with. No signature
    % is no signature: never the server's definition file.
    if isempty(sig)
        sig = struct();
    end
    encoding = prodserver.mcp.jsonrpc.toolEncoding(tool, sig=sig, def=def);

    % Assume "required" lists parameters in order. varargin must contain at
    % least numel(req) inputs.
    req = prodserver.mcp.internal.requiredNames(def, "inputSchema");

    if numel(req) > numel(varargin)
        error("prodserver:mcp:MissingRequiredArguments", ...
            "Required arguments are missing. Expected %d but got %d.", ...
            numel(req), numel(varargin));
    end

    for k = 1:numel(req)
        encoded = encodeArgument(tool, encoding, req(k), varargin{k});
        body.params.arguments.(req(k)) = encoded{1};
    end

    % n is the next unconsumed argument. An independent cursor, not the loop
    % variable above, which is unreliable when the range is empty -- as it
    % is for a tool with no required inputs (XD11c).
    n = numel(req) + 1;

    % A deployed archive's signature omits 'input' for a tool with no inputs
    % (ND12), so its absence means "no optional positional arguments".
    kind = ParameterKind.empty;
    names = string.empty;
    if hasField(sig, string(tool) + ".input.kind")
        kind = ParameterKind(sig.(tool).input.kind);
        names = string(sig.(tool).input.name);
    end

    % Optional positional
    while n <= numel(varargin) && n <= numel(kind) && ...
            kind(n) == ParameterKind.Optional
        encoded = encodeArgument(tool, encoding, names(n), varargin{n});
        body.params.arguments.(names(n)) = encoded{1};
        n = n + 1;
    end

    % TODO: Repeating positional

    % Name/Value pairs. <=, not <: a single stray argument must be reported,
    % not silently dropped (ND7).
    if n <= numel(varargin)
        nv = varargin(n:end);
        if mod(numel(nv),2) ~= 0
            error("prodserver:mcp:UnevenOptionalArguments", ...
                "Name/value arguments must appear in pairs, but " + ...
                "only an uneven number (%d) of arguments remain after " + ...
                "processing the required and optional positional arguments.", ...
                numel(nv));
        end
        for k = 1:numel(nv)/2
            encoded = encodeArgument(tool, encoding, nv{k*2-1}, nv{k*2});
            body.params.arguments.(nv{k*2-1}) = encoded{1};
        end
    end

    % A tool called with no arguments still sends an arguments object.
    if ~isfield(body.params, "arguments")
        body.params.arguments = struct();
    end
end

function encoded = encodeArgument(tool, encoding, name, value)
%encodeArgument Encode argument NAME of TOOL, as mcpEncode does. When the
%   tool's encoding can't carry the value, say which argument it is and
%   what the tool needs, not only what the encoding lacks.
    try
        encoded = prodserver.mcp.jsonrpc.mcpEncode(encoding, value);
    catch me
        if me.identifier ~= "prodserver:mcp:IncompatibleArgumentType"
            rethrow(me);
        end
        error(me.identifier, "Argument '%s' of tool %s: %s Build the " + ...
            "tool with encoding=""Invertible"" to pass it this value.", ...
            name, tool, me.message);
    end
end
