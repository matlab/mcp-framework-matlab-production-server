function contents = read_mcp_resource(url)
% Use this tool to read any MCP resource URI (mcp://...).
% You MUST call this tool whenever a resource URI is referenced —
% do not attempt to infer, summarize, or fabricate resource content.
% Always call this tool first before responding about any resource.

% Copyright 2026 The MathWorks

    arguments (Input)
        url (1,1) string % MCP resource URL
    end
    arguments (Output)
        contents (1,1) struct % The contents of the resource
    end

    contents = prodserver.mcp.handler.resource.contents(url);
    
    % [] fails the (1,1) struct validation for contents.
    if isempty(contents)
        contents.url = url;
        contents.mimeType = "text/plain";
        contents.text = "";
    end
end