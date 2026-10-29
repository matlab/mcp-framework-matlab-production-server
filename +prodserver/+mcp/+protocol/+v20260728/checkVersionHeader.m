function checkVersionHeader(pv, metaVersion)
%checkVersionHeader Raise -32020 if the version header contradicts _meta.
%   PV is the MCP-Protocol-Version header value ("" when absent) and
%   METAVERSION the version declared inside params._meta. This revision
%   carries the authoritative version in the body, so the header can only
%   agree with it or be wrong; an absent header is not a disagreement.
%
%   Called from two places, which is why the comparison lives here rather
%   than at either of them:
%
%   ProtocolRegistry.resolve makes this check before an adapter exists, and
%   has to. Picking the adapter from the header instead would route a
%   header/_meta disagreement to the 2025-06-18 adapter, which has no
%   equivalent check, and the mandated -32020 would go out as a 200.
%
%   v20260728.validateHeaders makes it again, as a second look at a question
%   already settled, because it is the header authority for this revision --
%   its Mcp-Method and Mcp-Name checks have no earlier counterpart -- and a
%   header validator that silently ignores the version header invites the
%   next caller to assume it was checked.
%
%   Both sites previously spelled the comparison out, with messages that had
%   already drifted apart ("the _meta protocol version" vs "_meta version").
%   Only the resolve copy is reachable through mcpHandler, so the suite was
%   pinning a string that never reached a client while the one that did was
%   unguarded. That message is the entire diagnosis a client gets for a
%   mandated -32020, so it exists once now.

% Copyright 2026 The MathWorks, Inc.

    if strlength(pv) > 0 && pv ~= metaVersion
        error('prodserver:mcp:HeaderMismatch', ...
            '%s header ''%s'' does not match the _meta protocol version ''%s''.', ...
            prodserver.mcp.MCPConstants.ProtocolVersion, pv, metaVersion);
    end
end
