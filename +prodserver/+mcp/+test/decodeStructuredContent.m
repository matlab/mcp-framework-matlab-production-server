function response = decodeStructuredContent(request, response)
%decodeStructuredContent Wire-decode structuredContent in a test response.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.jsonrpc.mcpDecode

    if ~isstruct(response) || ~isfield(response,'result') || ...
            ~isfield(response.result,'structuredContent')
        return
    end

    toolEncoding = prodserver.mcp.WireEncoding.Invertible;
    body = prodserver.mcp.internal.decodeBody(request);
    if isstruct(body) && isfield(body,'params') && ...
            isfield(body.params,'name')
        try
            d = load(MCPConstants.DefinitionFile);
            sig = d.(MCPConstants.DefinitionVariable).signatures;
            fcn = body.params.name;
            if isfield(sig,fcn) && isfield(sig.(fcn),'encoding')
                toolEncoding = prodserver.mcp.WireEncoding(sig.(fcn).encoding);
            end
        catch
        end
    end

    sc = response.result.structuredContent;
    flds = fieldnames(sc);
    allVals = cell(1,numel(flds));
    for k = 1:numel(flds)
        allVals{k} = sc.(flds{k});
    end
    decoded = mcpDecode(toolEncoding, allVals{:});
    for k = 1:numel(flds)
        sc.(flds{k}) = decoded{k};
    end
    response.result.structuredContent = sc;
end
