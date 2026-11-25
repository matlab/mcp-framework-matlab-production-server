function pv = headerVersion(request)
%headerVersion The MCP-Protocol-Version request header, "" when absent.
%   Protocol-neutral: the header is spelled the same way by every revision,
%   and what each revision makes of it differs. Read it here, decide
%   elsewhere. requestHeader guards a request with no headers.

% Copyright 2026 The MathWorks, Inc.

    pv = "";
    value = prodserver.mcp.internal.requestHeader(request, ...
        prodserver.mcp.MCPConstants.ProtocolVersion);
    if ~isempty(value)
        pv = strtrim(string(value));
    end
end
