function info = serverInfo(serverName)
%serverInfo The serverInfo every protocol revision reports.
%   info = serverInfo(serverName) has the server's name and version, and,
%   if SERVERNAME is not empty, its title: the archive name, from the
%   request path (see serverNameFromPath).

% Copyright 2026 The MathWorks, Inc.

    arguments
        serverName string = ""
    end

    import prodserver.mcp.MCPConstants

    info.name = MCPConstants.ServerName;
    if strlength(serverName) > 0
        info.title = serverName;
    end
    info.version = MCPConstants.ServerVersion;
end
