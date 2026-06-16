function body = toolsCall(tool,id,def,sig,varargin)
%toolsCall Create structure for JSONRPC MCP tools/call body.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.ParameterKind
    
    body.id = id;
    body.method = "tools/call";
    body.jsonrpc = MCPConstants.jrpcVersion;
    body.params.name = tool;
    
    % Assume "required" lists parameters in order. varargin must contain at
    % least numel(req) inputs.
    req = string(split(def.inputSchema.required,','));

    if numel(req) > numel(varargin)
        error("prodserver:mcp:MissingRequiredArguments", ...
            "Required arguments are missing. Expected %d but got %d.", ...
            numel(req), numel(varargin));
    end

    for n = 1:numel(req)
        body.params.arguments.(req(n)) = varargin{n};
    end
    if n < numel(varargin)
        n = n + 1;
        kind = ParameterKind(sig.(tool).input.kind);

        % Optional positional
        while n <= numel(varargin) && n <= numel(kind) && ...
                kind(n) == ParameterKind.Optional
            body.params.arguments.(sig.(tool).input.name{n}) = varargin{n};
            n = n + 1;
        end

        % TODO: Repeating positional
        
        % Name/Value pairs
        if n < numel(varargin)
            varargin = varargin(n:end);
            if mod(numel(varargin),2) ~= 0
                error("prodserver:mcp:UnevenOptionalArguments", ...
                    "Name/value arguments must appear in pairs, but " + ...
                    "only an uneven number (%d) of arguments remain after " + ...
                    "processing the required and optional positional arguments.");
            end
            N = numel(varargin)/2;
            for n = 1:N
                body.params.arguments.(varargin{n*2-1}) = varargin{n*2};
            end
        end
    end
end