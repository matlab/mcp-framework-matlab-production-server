function items = list(endpoint, type, opts)
% List all of the MCP primitives of TYPE available at ENDPOINT.
% Returns a cell array of MATLAB structures corresponding to the MCP
% protocol JSON description of the available primitives, or empty if none
% exist. Structure fields vary by TYPE.
%
% Examples:
%
%    tools = prodserver.mcp.list("http://localhost:9910/cleanSignal/mcp", "Tool")
%    tools{1} =
%        struct with fields:
%                  name: 'cleanSignal'
%           description: 'Removes periodic noise from a signal using ' ...
%           inputSchema: [1x1 struct]
%          outputSchema: [1x1 struct]
%                server: [1x1 struct]
%
%    resources = prodserver.mcp.list("http://localhost:9910/myServer/mcp", "Resource")
%    resources{1} =
%        struct with fields:
%                   uri: 'mcp://protocol/tools/wire-format/parameters/encoding_rules'
%                  name: 'encoding_rules'
%              mimeType: 'text/plain'
%                server: [1x1 struct]
%
% See also: prodserver.mcp.Primitive, prodserver.mcp.read, prodserver.mcp.exist

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        type (1,1) prodserver.mcp.Primitive
        opts.protocol string = "discover"
        opts.timeout double {mustBePositive} = 30
        opts.retry double {mustBePositive} = 10
        opts.delay double {mustBePositive} = 2
    end

    try
        items = doList(endpoint, type, opts);
    catch me
        if opts.protocol == "discover" && prodserver.mcp.protocol.isProtocolError(me)
            prodserver.mcp.client.Adapter.create(endpoint, action="clear");
            items = doList(endpoint, type, opts);
        else
            rethrow(me);
        end
    end
end

function items = doList(endpoint, type, opts)
    client = prodserver.mcp.client.Adapter.create(endpoint, ...
        protocol=opts.protocol);
    client.connect(require=type, timeout=opts.timeout, ...
        delay=opts.delay, retry=opts.retry);
    cleanup = onCleanup(@()client.disconnect());

    try
        items = client.list(type, timeout=opts.timeout, ...
            delay=opts.delay, retry=opts.retry);
        items = items.(mcpName(type));

        server.type = "http";
        server.url = endpoint;
        if iscell(items)
            for n = 1:numel(items)
                items{n}.server = server;
            end
        elseif ~isempty(items) && isstruct(items)
            [items.server] = server;
            items = num2cell(items);
        end

    catch me
        if strcmpi(me.identifier, "prodserver:mcp:HttpError") && ...
                contains(me.message, "404: Not Found", IgnoreCase=true)
            error("prodserver:mcp:UnknownServer", ...
                "Unknown MCP server %s.", endpoint);
        end
        rethrow(me);
    end
end

