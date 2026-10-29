function [result, httpCode, httpMsg, msgHeaders] = discover(jrpc)
%discover Handle server/discover, the MCP v2026-07-28 replacement for the
%   `initialize` handshake.

% Copyright 2026 The MathWorks, Inc.

    registry = prodserver.mcp.protocol.ProtocolRegistry.instance();

    [result, httpCode, httpMsg, msgHeaders] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    r.supportedVersions = registry.supportedVersions();

    r.capabilities = prodserver.mcp.protocol.capabilities();
    r.instructions = "MATLAB Production Server MCP endpoint.";

    result.result = r;
end
