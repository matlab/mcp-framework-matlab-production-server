function contents = read_mcp_resource(uri)
% Use this tool to read any MCP resource URI (mcp://...).
% You MUST call this tool whenever a resource URI is referenced —
% do not attempt to infer, summarize, or fabricate resource content.
% Always call this tool first before responding about any resource.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        uri (1,1) string % MCP resource URI
    end
    arguments (Output)
        contents (1,1) struct % The contents of the resource
    end

    contents = prodserver.mcp.handler.resource.contents(uri);

    % A URI that matches no resource is a failed read, and saying so is the
    % whole point of the instruction above. This branch used to synthesize a
    % resource -- text/plain with empty text -- purely to satisfy the (1,1)
    % struct output validation, which told the caller the resource existed and
    % was blank. An LLM that mistypes a URI then has no way to tell a missing
    % resource from an empty one, and the fabricated answer is the one thing
    % this tool promises not to produce.
    %
    % tools/call reports this through the isError convention over HTTP 200: the
    % protocol succeeded and the tool ran, it just could not do what was asked.
    % resources/read raises the same identifier and maps it to JSON-RPC -32002,
    % so both ways of reading a resource agree that this one is absent.
    if isempty(contents)
        error("prodserver:mcp:ResourceNotFound", ...
            "Resource '%s' not found on this MCP server.", uri);
    end
end
