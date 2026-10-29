function archive = archiveFromEndpoint(uri)
%archiveFromEndpoint The archive an MCP endpoint names.
%   archive = archiveFromEndpoint(uri) is <archive> for an endpoint
%   .../<archive>/mcp, and "" for an address that names no archive, such
%   as a plain server address.

% Copyright 2026 The MathWorks, Inc.

    archive = "";
    found = extract(string(uri), "/" + wildcardPattern(Except="/") + ...
        prodserver.mcp.MCPConstants.MCP + textBoundary("end"));
    if ~isempty(found)
        parts = split(found(1), "/");
        archive = parts(2);
    end
end
