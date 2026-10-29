function body = stampMeta(body, version)
%stampMeta Add the _meta a 2026-07-28 request carries.
%   body = stampMeta(body, version) sets params._meta's protocol version to
%   VERSION and its client capabilities to none, creating params if BODY
%   has none. The client adapter and the test envelope both use this.

% Copyright 2026 The MathWorks, Inc.

    arguments
        body struct
        version (1,1) string = prodserver.mcp.protocol.v20260728.Constants.Version
    end

    import prodserver.mcp.MCPConstants
    C = prodserver.mcp.protocol.v20260728.Constants;
    if ~isfield(body, 'params')
        body.params = struct();
    end
    body.params.(MCPConstants.MetaField).(C.MetaProtocolVersion_Field) = version;
    body.params.(MCPConstants.MetaField).(C.MetaCapabilities_Field) = struct();
end
