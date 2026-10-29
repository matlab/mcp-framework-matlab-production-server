function encoded = mcpEncode(encoding, varargin)
%mcpEncode Encode MATLAB values for MCP wire transmission.
%
%   ENCODED = mcpEncode(ENCODING, V1, V2, ...) encodes each value according
%   to the specified wire encoding strategy and returns a cell array of
%   encoded values.
%
%   ENCODING is a prodserver.mcp.WireEncoding value:
%     Invertible — full typed-wrapper encoding (lossless round-trip)
%     JSON       — bare jsonencode-compatible values (no wrappers)
%
%   See also: mcpDecode, mcpWireEncodeValue, WireEncoding

% Copyright 2026 The MathWorks, Inc.

    switch encoding
        case prodserver.mcp.WireEncoding.Invertible
            encoded = cellfun(@prodserver.mcp.jsonrpc.mcpWireEncodeValue, ...
                varargin, UniformOutput=false);
        case prodserver.mcp.WireEncoding.JSON
            % jsonencode would write datetimes and durations as
            % locale-dependent display text, and a timetable as {}.
            encoded = cellfun(@prodserver.mcp.jsonrpc.plainJSONValue, ...
                varargin, UniformOutput=false);
    end
end
