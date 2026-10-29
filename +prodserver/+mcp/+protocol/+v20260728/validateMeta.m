function [version, capabilities, clientInfo] = validateMeta(jrpc)
%validateMeta Extract and validate the _meta fields a request must carry.
%   Specific to v2026-07-28, which replaced the handshake with a per-request
%   _meta envelope: every request restates the protocol version and the
%   client's capabilities, so there is nothing to remember between requests.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.hasField
    C = prodserver.mcp.protocol.v20260728.Constants;
    MetaField = prodserver.mcp.MCPConstants.MetaField;

    if ~hasField(jrpc, "params." + MetaField)
        % Names the revision, not a category. This message goes out on the
        % wire, where "stateless requests must..." left the client guessing
        % which of the versions it might speak was being described -- and
        % would have become actively wrong as soon as a second revision
        % carried _meta.
        error("prodserver:mcp:MissingMeta", ...
            "MCP %s requests must include _meta in params.", C.Version);
    end
    meta = jrpc.params.(MetaField);

    % _meta is present -- that is what routed the request here -- so an empty
    % version means the field is absent, not that the request said nothing.
    % The two cases carry different identifiers, which is why this check
    % cannot be folded into metaVersion.
    version = prodserver.mcp.protocol.v20260728.metaVersion(jrpc);
    if strlength(version) == 0
        error("prodserver:mcp:MissingProtocolVersion", ...
            "Missing io.modelcontextprotocol/protocolVersion in _meta.");
    end

    if isfield(meta, C.MetaCapabilities_Field)
        capabilities = meta.(C.MetaCapabilities_Field);
    elseif isfield(meta, C.MetaCapabilitiesAlt_Field)
        % Some clients send "capabilities" instead of "clientCapabilities"
        capabilities = meta.(C.MetaCapabilitiesAlt_Field);
    else
        error("prodserver:mcp:MissingCapabilities", ...
            "Missing io.modelcontextprotocol/clientCapabilities in _meta.");
    end

    clientInfo = [];
    if isfield(meta, C.MetaClientInfo_Field)
        clientInfo = meta.(C.MetaClientInfo_Field);
    end
end
