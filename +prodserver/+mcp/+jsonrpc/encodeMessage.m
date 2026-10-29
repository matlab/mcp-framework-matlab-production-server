function json = encodeMessage(message)
%encodeMessage Encode a MATLAB struct as JSON with MCP field-name aliases.
%
%   JSON = encodeMessage(MESSAGE) calls jsonencode on MESSAGE, then
%   replaces MATLAB-safe field names with their wire equivalents:
%     dollarDefs -> $defs
%     x_meta     -> _meta
%
%   Only object keys are renamed (see restoreFieldNames), so string
%   values pass through unchanged.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    json = prodserver.mcp.jsonrpc.restoreFieldNames(jsonencode(message), {
        MCPConstants.DefsField, MCPConstants.DefsJSON
        MCPConstants.MetaField, MCPConstants.MetaJSON});
end
