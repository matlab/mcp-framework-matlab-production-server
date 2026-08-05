function tf = isMcpTypedWrapper(j)
%isMcpTypedWrapper  True if struct looks like an MCP typed wrapper on the wire.
%
%   TF = isMcpTypedWrapper(J) returns true when struct J has a "type" field
%   AND at least one MCP companion field ("size", "data", "seconds",
%   "categories", "variables", or "rowTimes").  Such a struct is
%   indistinguishable from an MCP typed wrapper after JSON round-trip.
%
%   Used by mcpWireDecodeValue (to decide whether to dispatch to typed
%   decoding) and by mcpWireEncodeValue (to force struct-array encoding
%   when a scalar struct would otherwise produce an ambiguous JSON object).

% Copyright 2026 The MathWorks, Inc.

if ~isfield(j, 'type')
    tf = false;
    return
end

companions = {'size','data','seconds','categories','variables','rowTimes'};
tf = any(isfield(j, companions));
end
