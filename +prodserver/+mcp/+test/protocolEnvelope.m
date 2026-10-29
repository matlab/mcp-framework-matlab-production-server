function [rows, body] = protocolEnvelope(protocol, body)
%protocolEnvelope Add a protocol revision's envelope to a test request.
%   [ROWS, BODY] = protocolEnvelope(PROTOCOL, BODY) returns the header rows
%   (an Nx2 cell, the shape request.Headers uses) and the updated decoded
%   JSON-RPC BODY for a request sent under PROTOCOL.
%
%     2025-06-18  a fresh Mcp-Session-Id row; BODY unchanged.
%     2026-07-28  params._meta added to BODY; MCP-Protocol-Version,
%                 Mcp-Method and (where the method names a thing) Mcp-Name.
%
%   The one place the test harnesses build an envelope. The server enforces
%   the 2026-07-28 headers strictly, so a harness that builds them in one
%   helper and not another turns every test built on the other red -- the
%   test mixin's hand-built copy once omitted Mcp-Method and Mcp-Name and
%   every 2026-07-28 build-integration case failed.
%
%   The header set comes from the production rule (messageHeaders), so the
%   harness cannot drift from the server it is exercising. That does make
%   this symmetric with the code under test, which is exactly the weakness
%   §6.2 of the conformance plan warns about -- so the sentinel format
%   itself is pinned independently, against literal expected bytes, in
%   tHeaderSentinel. This helper's job is to produce valid requests; that
%   test's job is to prove "valid" means what the spec says.

% Copyright 2026 The MathWorks, Inc.

    arguments
        protocol (1,1) string
        body struct
    end

    import prodserver.mcp.MCPConstants

    if protocol == prodserver.mcp.protocol.v20250618.Constants.Version
        rows = {prodserver.mcp.protocol.v20250618.Constants.SessionId, ...
            matlab.lang.internal.uuid};
        return
    end

    body = prodserver.mcp.protocol.v20260728.stampMeta(body, protocol);

    rows = [{MCPConstants.ProtocolVersion, char(protocol)}; ...
        prodserver.mcp.protocol.v20260728.messageHeaders(body)];
end
