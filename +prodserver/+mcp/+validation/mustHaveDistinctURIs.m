function mustHaveDistinctURIs(resources)
% mustHaveDistinctURIs Error if two RESOURCES have the same uri.
%
%   mustHaveDistinctURIs(resources) checks a struct array or cell array of
%   resource structures, each with a uri field. A URI identifies exactly
%   one resource, as MCP requires: a server with two under one URI builds
%   and deploys, but no client can read either (prodserver.mcp.read raises
%   NonUniqueResource).

% Copyright 2026 The MathWorks, Inc.

    if iscell(resources)
        uris = cellfun(@(r) string(r.uri), resources);
    else
        uris = arrayfun(@(r) string(r.uri), resources);
    end
    [distinct, ~, which] = unique(uris, "stable");
    counts = accumarray(which(:), 1);
    dup = find(counts > 1, 1);
    if ~isempty(dup)
        at = string(find(uris == distinct(dup)));
        list = strjoin(at(1:end-1), ", ") + " and " + at(end);
        throwAsCaller(MException("prodserver:mcp:DuplicateResourceURI", ...
            "Resources %s share the URI '%s'. A URI must identify " + ...
            "exactly one resource: give each resource its own.", ...
            list, distinct(dup)));
    end
end
