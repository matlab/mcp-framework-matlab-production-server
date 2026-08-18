function decoded = mcpDecode(encoding, varargin)
%mcpDecode Decode MCP wire values back to MATLAB.
%
%   DECODED = mcpDecode(ENCODING, V1, V2, ...) decodes each jsondecode'd
%   value according to the specified wire encoding strategy and returns a
%   cell array of decoded MATLAB values.
%
%   ENCODING is a prodserver.mcp.WireEncoding value:
%     Invertible — decode typed wrappers back to native MATLAB types
%     JSON       — pass through as-is (values are bare JSON)
%     Hybrid     — decode typed wrappers back to native MATLAB types
%
%   See also: mcpEncode, mcpWireDecodeValue, WireEncoding

% Copyright 2026 The MathWorks, Inc.

    switch encoding
        case prodserver.mcp.WireEncoding.Invertible
            decoded = cellfun(@prodserver.mcp.jsonrpc.mcpWireDecodeValue, ...
                varargin, UniformOutput=false);
        case prodserver.mcp.WireEncoding.JSON
            decoded = varargin;
        case prodserver.mcp.WireEncoding.Hybrid
            decoded = cellfun(@prodserver.mcp.jsonrpc.mcpWireDecodeValue, ...
                varargin, UniformOutput=false);
    end
end
