function pv = headerVersion(request)
%headerVersion The MCP-Protocol-Version request header, "" when absent.
%   Protocol-neutral: the header is spelled the same way by every revision,
%   and what each revision makes of it differs. Read it here, decide
%   elsewhere.
%
%   The guard matters as much as the read. Headers arrive as an Nx2 cell
%   array, and getHeaderValue rejects one that is not two columns wide --
%   which an empty {} is not -- so every caller that might see a request
%   with no headers has to check first. Hand-rolled copies of that guard
%   were the only thing standing between a header-less request and an
%   error about name-value pairs.

% Copyright 2026 The MathWorks, Inc.

    pv = "";
    if isempty(request) || ~isfield(request, 'Headers') || ...
            isempty(request.Headers)
        return
    end
    value = prodserver.mcp.internal.getHeaderValue( ...
        prodserver.mcp.MCPConstants.ProtocolVersion, request.Headers);
    if ~isempty(value)
        pv = strtrim(string(value));
    end
end
