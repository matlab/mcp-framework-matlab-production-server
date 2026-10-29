function result = cacheHints(result, method)
%cacheHints Add ttlMs and cacheScope to a complete result that may be cached.
%   RESULT is the JSON-RPC result member, already stamped with resultType.
%   2026-07-28 requires both fields on a complete result from server/discover,
%   tools/list, prompts/list, resources/list, resources/templates/list and
%   resources/read (CacheableResult). This server implements every one of
%   them except prompts/list.
%
%   Every other result is returned unchanged. Its schema would allow the
%   fields, but a TTL on a tool call means nothing and would mislead a
%   client. So would one on an input_required result, which the spec says
%   carries no caching hints.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    if ~isfield(result, "resultType") || string(result.resultType) ~= "complete"
        return
    end

    switch lower(string(method))
        case {"server/discover", "tools/list", "resources/list", ...
                "resources/templates/list"}
            result.ttlMs = MCPConstants.DefinitionCacheTtlMs;
            result.cacheScope = MCPConstants.DefinitionCacheScope;
        case "resources/read"
            result.ttlMs = MCPConstants.ResourceCacheTtlMs;
            result.cacheScope = MCPConstants.ResourceCacheScope;
    end
end
