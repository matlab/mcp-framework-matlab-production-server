function json = restoreJSONFields(json)
%restoreJSONFields Replace MATLAB-mangled _meta sub-field names with MCP wire names.
%   The _meta sub-fields this revision defines. Revision-neutral names are
%   not listed here: the base Adapter.postEncode applies those for every
%   revision, and repeating them would make the shared set look optional.

% Copyright 2026 The MathWorks, Inc.

    C = prodserver.mcp.protocol.v20260728.Constants;
    pairs = {
        C.MetaProtocolVersion_Field, C.MetaProtocolVersion_JSON
        C.MetaCapabilities_Field,    C.MetaCapabilities_JSON
        C.MetaClientInfo_Field,      C.MetaClientInfo_JSON
        C.MetaLogLevel_Field,        C.MetaLogLevel_JSON
        C.MetaServerInfo_Field,      C.MetaServerInfo_JSON
        C.MetaSubscriptionId_Field,  C.MetaSubscriptionId_JSON
    };
    json = prodserver.mcp.jsonrpc.restoreFieldNames(json, pairs);
end
