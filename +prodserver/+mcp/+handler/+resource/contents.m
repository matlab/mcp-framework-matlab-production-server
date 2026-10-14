function data = contents(uri)
% contents Read a named resource from the MCP tool definition file.
%   Returns [] when no resource matches, which every caller must handle:
%   "absent" is not the same answer as "present and empty".
%
%   The parameter is a URI, not a URL. It is matched against the resource's
%   own uri field and copied into the uri field of the result, and MCP names
%   that field uri throughout; calling it url here left one concept with two
%   names inside a single ten-line function.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    
    % Reading a resource returns the contents. Use text for text
    % and blob for binary.
    data = [];

    % Load the MCP tool definition
    svc = prodserver.mcp.handler.toolServices;

    % Get the list of all resources, which is a cell array, since resource
    % structures are not all required to have the same fields.
    rList = svc.(MCPConstants.ResourceVariable);
    u = cellfun(@(r)string(r.uri),rList);
    rI = strcmp(u,uri);

    % Allow zero or one resource with the given URI.
    if nnz(rI) == 1
        data.uri = uri;
        data.mimeType = rList{rI}.mimeType;
        if prodserver.mcp.jsonrpc.isMIMETypeText(data.mimeType)
            data.text = rList{rI}.contents;
        else
            data.blob = rList{rI}.contents;
        end
    elseif nnz(rI) ~= 0
        error("prodserver:mcp:AmbiguousResourceURL", "Expecting zero " + ...
            "or one resource with URI %s but found %d.", uri, nnz(rI));
    end
    
end

