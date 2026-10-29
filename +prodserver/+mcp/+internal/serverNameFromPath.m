function name = serverNameFromPath(path)
%serverNameFromPath The <server> segment of an MCP request path.
%   NAME = serverNameFromPath(PATH) returns "server" for "/server/mcp", and
%   "" when PATH names no server. On Production Server that segment is the
%   archive name. PATH may also be a request, whose Path is used.
%
%   Shared by mcpHandler, which needs the name for its metrics, and by both
%   protocol revisions, which report it as serverInfo.title -- the one
%   value that tells several servers hosted on the same Production Server
%   instance apart in a single client.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.Constants

    % split puts "" ahead of the leading separator, so <server> is the
    % second element.
    name = "";
    if isstruct(path)
        % A request: its Path, if it has one.
        if ~isfield(path, "Path")
            return
        end
        path = path.Path;
    end
    if isempty(path) || ~(ischar(path) || isstring(path))
        return
    end
    parts = split(string(path), Constants.URISep);
    if numel(parts) >= 2 && ~ismissing(parts(2))
        name = parts(2);
    end
end
