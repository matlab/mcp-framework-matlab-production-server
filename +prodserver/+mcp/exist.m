function tf = exist(endpoint, identifier, type, opts)
%exist Check existence of tools, resources and prompts on the given server.
%
%   tf = exist(endpoint, identifier, type) returns TRUE if IDENTIFIER
%       exists as a TYPE on the MCP server at ENDPOINT. For tools,
%       IDENTIFIER is the tool name. For resources, IDENTIFIER is the
%       resource URI. IDENTIFIER may be a list; TF is the same size. TYPE
%       is either a scalar, which applies to every IDENTIFIER, or the same
%       size as IDENTIFIER.
%
% See also: prodserver.mcp.Primitive

% Copyright 2025-2026 The MathWorks, Inc.


    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        identifier string { mustBeNonempty }
        type prodserver.mcp.Primitive { mustBeNonempty }
        opts.protocol string = "discover"
        opts.timeout double {mustBePositive} = 30
        opts.retry double {mustBePositive} = 10
        opts.delay double {mustBePositive} = 2
    end

    if isscalar(type)
        type = repmat(type, size(identifier));
    elseif ~isequal(size(type), size(identifier))
        error("prodserver:mcp:SizeMismatch", ...
            "TYPE must be a scalar or the same size as IDENTIFIER " + ...
            "(%s), not %s.", mat2str(size(identifier)), mat2str(size(type)));
    end

    try
        tf = doExist(endpoint, identifier, type, opts);
    catch me
        if opts.protocol == "discover" && prodserver.mcp.protocol.isProtocolError(me)
            prodserver.mcp.client.Adapter.create(endpoint, action="clear");
            tf = doExist(endpoint, identifier, type, opts);
        else
            rethrow(me);
        end
    end
end

function tf = doExist(endpoint, identifier, type, opts)
    tf = false(size(identifier));

    % Each kind of primitive is listed once, however many identifiers
    % refer to it.
    kinds = unique(type);

    client = prodserver.mcp.client.Adapter.create(endpoint, ...
        protocol=opts.protocol);
    client.connect(require=kinds, timeout=opts.timeout, ...
        retry=opts.retry, delay=opts.delay);
    cleanup = onCleanup(@()client.disconnect()); %#ok<NASGU>

    items = client.list(kinds, timeout=opts.timeout, ...
        retry=opts.retry, delay=opts.delay);

    for k = 1:numel(kinds)
        ids = listedIds(items.(mcpName(kinds(k))), kinds(k));
        mine = type == kinds(k);
        tf(mine) = arrayfun(@(id)nnz(strcmp(id, ids)) == 1, identifier(mine));
    end
end

function ids = listedIds(p, kind)
%listedIds The names (or, for resources, URIs) of the listed primitives.
    if kind == prodserver.mcp.Primitive.Resource
        field = "uri";
    else
        field = "name";
    end

    if iscell(p)
        ids = cellfun(@(r)string(r.(field)), p);
    elseif isstruct(p) && ~isempty(p)
        ids = string({p.(field)});
    else
        ids = string.empty;
    end
end
