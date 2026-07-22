function [result, httpCode, httpMsg, msgHeaders] = list(jrpc)
%list Handle MCP resources/list request. Returns all resource descriptors
% (without contents) from the definition file.

% Copyright 2025-2026, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    % Listing a resource returns all the fields except the contents.
    d = load(MCPConstants.DefinitionFile);
    rList = d.(MCPConstants.ResourceVariable);
    rsrc.resources = cellfun(@(r)rmfield(r,"contents"),rList,...
        UniformOutput=false);

    result.result = rsrc;
end
