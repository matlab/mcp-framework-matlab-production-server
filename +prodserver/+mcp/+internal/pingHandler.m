function response = pingHandler(request)
%pingHandler Accept <archive>/ping and return 'pong'. Makes sure the server
%is awake and responsive.
%   A deployed archive also names its build in the MATLAB-MCP-Archive-UUID
%   header (see archiveUUID), so deploy can tell it from the archive it
%   replaces: the server answers with the old one for several seconds after
%   an update. The body stays 'pong' for the callers that compare it.

% Copyright 2025-2026 The MathWorks, Inc.

    data = prodserver.mcp.MCPConstants.Pong;

    headers = {};
    uuid = prodserver.mcp.internal.archiveUUID();
    if strlength(uuid) > 0
        headers = {prodserver.mcp.internal.Constants.ArchiveUUIDHeader, ...
            char(uuid)};
    end

    [code, reason] = prodserver.mcp.handler.internal.httpStatus(200);
    response = prodserver.mcp.internal.prepareResponse(code,reason,...
        ct="text/plain",body=data,headers=headers);

end
