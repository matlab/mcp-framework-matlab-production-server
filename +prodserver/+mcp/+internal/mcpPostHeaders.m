function headers = mcpPostHeaders()
%mcpPostHeaders The headers every MCP POST the client sends must carry.
%   Content-Type, and the Accept header both 2025-06-18 and 2026-07-28
%   require: "The client MUST include an Accept header listing both
%   application/json and text/event-stream as supported content types" (G15).
%
%   Revision-independent, so it lives here rather than in either adapter's
%   prepareRequest, and every MCP POST builder -- Adapter.buildRequest (for
%   send and probe) and the initialize handshake -- starts from it. Deliberately
%   not added to protocolHeaders: that list's only production caller,
%   internal.signature, POSTs text/plain to the non-MCP signature handler,
%   which produces neither of these content types.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants

    headers = [
        matlab.net.http.HeaderField(MCPConstants.ContentType, ...
            char(Constants.MIMETypeJSON)), ...
        matlab.net.http.HeaderField(MCPConstants.Accept, ...
            MCPConstants.AcceptMCP)
        ];
end
