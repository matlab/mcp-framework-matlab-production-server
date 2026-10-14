function body = toolsCall(tool,id,def,sig,varargin)
%toolsCall Create structure for JSONRPC MCP tools/call body.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.ParameterKind
    import prodserver.mcp.jsonrpc.mcpEncode

    body.id = id;
    body.method = "tools/call";
    body.jsonrpc = MCPConstants.jrpcVersion;
    body.params.name = tool;

    % Determine encoding from signature if available.
    if isfield(sig,tool) && isfield(sig.(tool),'encoding')
        encoding = prodserver.mcp.WireEncoding(sig.(tool).encoding);
    else
        encoding = prodserver.mcp.WireEncoding.JSON;
    end

    % Assume "required" lists parameters in order. varargin must contain at
    % least numel(req) inputs.
    %
    % A tool with no required inputs may omit the "required" key, but it may
    % equally advertise it empty -- a live server answers tools/list for a
    % zero-input tool with "required":[], which jsondecode turns into a 0x0
    % double. split() demands text and throws MustBeCharCellArrayOrString on
    % that, so testing only for the key's presence left every zero-input tool
    % uncallable from this client even though the server handles it correctly.
    % Absent and empty mean the same thing here: nothing is required.
    if isfield(def.inputSchema,"required") && ~isempty(def.inputSchema.required)
        req = string(split(def.inputSchema.required,','));
    else
        req = string.empty(0,1);
    end

    if numel(req) > numel(varargin)
        error("prodserver:mcp:MissingRequiredArguments", ...
            "Required arguments are missing. Expected %d but got %d.", ...
            numel(req), numel(varargin));
    end

    % One cursor over varargin, independent of any loop variable. MATLAB
    % assigns a loop variable the empty range when the loop body never runs,
    % so deriving the cursor from the required-argument loop and guarding the
    % rest behind it would silently drop every argument supplied to a tool
    % that has no required inputs.
    n = 1;
    for k = 1:numel(req)
        encoded = mcpEncode(encoding, varargin{n});
        body.params.arguments.(req(k)) = encoded{1};
        n = n + 1;
    end

    % Optional positional
    if isfield(sig,tool) && ...
            prodserver.mcp.internal.hasField(sig.(tool),"input.kind")
        kind = ParameterKind(sig.(tool).input.kind);
    else
        kind = ParameterKind.empty;
    end
    while n <= numel(varargin) && n <= numel(kind) && ...
            kind(n) == ParameterKind.Optional
        encoded = mcpEncode(encoding, varargin{n});
        body.params.arguments.(sig.(tool).input.name{n}) = encoded{1};
        n = n + 1;
    end

    % TODO: Repeating positional

    % Name/Value pairs
    if n <= numel(varargin)
        rest = varargin(n:end);
        if mod(numel(rest),2) ~= 0
            error("prodserver:mcp:UnevenOptionalArguments", ...
                "Name/value arguments must appear in pairs, but an uneven " + ...
                "number (%d) of arguments remain after processing the " + ...
                "required and optional positional arguments.", numel(rest));
        end
        for k = 1:numel(rest)/2
            encoded = mcpEncode(encoding, rest{k*2});
            body.params.arguments.(rest{k*2-1}) = encoded{1};
        end
    end
end