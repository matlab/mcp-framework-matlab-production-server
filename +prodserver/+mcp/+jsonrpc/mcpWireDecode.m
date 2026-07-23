function value = mcpWireDecode(j)
%mcpWireDecode  Decode an MCP JSON-encoded value back to a MATLAB value.
%
%   VALUE = mcpWireDecode(J) decodes J, which must be a JSON string
%   containing a MATLAB value encoded by mcpWireEncode().
%
%   By design x == mcpWireDecode(mcpWireEncode(x)).
%
%   See also: mcpWireDecodeValue, mcpWireEncode, jsondecode

% Copyright 2026 The MathWorks, Inc.

    j = jsondecode(j);
    value = prodserver.mcp.jsonrpc.mcpWireDecodeValue(j);
end
