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

    % struct2cell and cell2struct promise strict fieldname order.
    sc = response.result.structuredContent;
    c = struct2cell(sc);
    decoded = mcpDecode(toolEncoding,c{:});
    decoded = decoded(:);
    response.result.structuredContent = cell2struct(decoded,fieldnames(sc)');
end
