function rows = messageHeaders(jrpc)
%messageHeaders The per-message headers 2026-07-28 requires of a request.
%   ROWS = messageHeaders(JRPC) returns an Nx2 cell of char {name, value}
%   rows for the JSON-RPC request JRPC: Mcp-Method always, and Mcp-Name for
%   the methods that name a thing. The MCP-Protocol-Version header is not
%   here: it is per-connection, not per-message, and comes from the
%   client's protocolHeaders.
%
%   The one place these rows are built. The client sends them and the test
%   harness forges them; the server enforces them strictly
%   (validateHeaders), so a copy that omits one turns a correct request
%   into a -32020. The rule for which methods need Mcp-Name is
%   nameFromParams', shared with the server.

% Copyright 2026 The MathWorks, Inc.

    C = prodserver.mcp.protocol.v20260728.Constants;

    rows = {C.McpMethod, char(string(jrpc.method))};

    [bodyName, nameRequired] = ...
        prodserver.mcp.protocol.v20260728.nameFromParams(jrpc);
    if nameRequired && strlength(bodyName) > 0
        % Encoded unconditionally -- encodeHeaderValue decides whether the
        % sentinel is actually needed.
        rows = [rows; {C.McpName, char( ...
            prodserver.mcp.protocol.v20260728.encodeHeaderValue(bodyName))}];
    end
    % No else: a name-requiring method whose params carry no name is a
    % malformed request, and inventing a header value would turn the
    % server's precise -32602 about the missing field into a -32020 about a
    % header the caller never set.
end
