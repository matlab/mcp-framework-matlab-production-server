classdef Constants
%Constants Protocol-specific constants for MCP v2025-06-18.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Version = "2025-06-18"

        % How a tools/call reports arguments that fail validation.
        %   2025-06-18 lists invalid arguments among the protocol errors, so a
        %   tools/call whose arguments fail the tool's inputSchema gets -32602.
        InputErrorsAreToolErrors = false

        % MCP session header
        SessionId = 'Mcp-Session-Id'

        % MCP resource-not-found error code. Specific to this revision:
        % 2026-07-28 MUST NOT emit it, so it is not in MCPConstants.
        ErrorResourceNotFound = -32002

        % Unsupported protocol version. 2025-06-18 defines no code for this,
        % so it borrows 2026-07-28's, deliberately -- see
        % Adapter.preDetectionError. This is the one place this revision
        % names the later one, so the dependency is visible, not scattered.
        ErrorUnsupportedVersion = ...
            prodserver.mcp.protocol.v20260728.Constants.ErrorUnsupportedVersion

        % HTTP session ID components — RFC 7329
        SessionIDPrefix = "SID"
        SessionIDSep = ":"
        SessionIDType = "MathWorks-Production-MCP-Server"
        SessionIDHeader = "Session-ID"
        SessionIDPattern = ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDPrefix + ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDSep + ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDType + ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDSep + ...
            asManyOfPattern(wildcardPattern(Except=prodserver.mcp.protocol.v20250618.Constants.SessionIDSep)) + ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDSep + ...
            wildcardPattern(36)
        SessionIDAtEnd = lookBehindBoundary("/") + ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDPrefix + ...
            prodserver.mcp.protocol.v20250618.Constants.SessionIDSep + ...
            wildcardPattern(Except="/") + ...
            textBoundary("end")
    end

end
