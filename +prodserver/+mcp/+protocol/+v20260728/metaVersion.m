function version = metaVersion(jrpc)
%metaVersion The protocol version a request declares in params._meta.
%   Returns "" when the request carries no params._meta, or a _meta that
%   declares no version. Callers that must tell those two cases apart --
%   only validateMeta does, because they carry different error codes --
%   test for params._meta themselves first.
%
%   Three call sites read this field for three different reasons: routing
%   (Adapter.statedVersion, which ProtocolRegistry.resolve calls),
%   validation (validateMeta) and rebuilding the mandated `requested`
%   payload on an unsupported version (mapErrorCode). The field name is awkward enough -- a JSON key
%   with dots in it, mangled by jsondecode into
%   io_modelcontextprotocol_protocolVersion -- that spelling out the access
%   three times is how one of them ends up reading a field that is not there.
%
%   Note what is NOT on that list: the per-revision tool-call metric. What a
%   request DECLARES here and which adapter SERVES it are different questions
%   whenever an alias is involved, and a metric wants the latter, so
%   handler.tools.call takes the serving revision as an argument instead.

% Copyright 2026 The MathWorks, Inc.

    C = prodserver.mcp.protocol.v20260728.Constants;
    MetaField = prodserver.mcp.MCPConstants.MetaField;

    version = "";
    path = "params." + MetaField + "." + C.MetaProtocolVersion_Field;
    if prodserver.mcp.internal.hasField(jrpc, path)
        version = strtrim(string( ...
            jrpc.params.(MetaField).(C.MetaProtocolVersion_Field)));
    end
end
