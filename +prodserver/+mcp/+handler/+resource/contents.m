function data = contents(url)
% contents Read a named resource from the MCP tool definition file.

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
    rI = strcmp(u,url);

    % Allow zero or one resource with the given url.
    if nnz(rI) == 1
        data.uri = url;
        data.mimeType = rList{rI}.mimeType;
        if prodserver.mcp.jsonrpc.isMIMETypeText(data.mimeType)
            data.text = rList{rI}.contents;
        else
            data.blob = rList{rI}.contents;
        end
    elseif nnz(rI) ~= 0
        error("prodserver:mcp:AmbiguousResourceURL", "Expecting zero " + ...
            "or one resource with URL %s but found %d.", url, nnz(rI));
    end
    
end

