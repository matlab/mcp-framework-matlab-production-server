function saveJSON(file,x,opts)
% saveJSON Save x to file in JSON.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        file string
        x
        opts.format prodserver.mcp.WireEncoding = "Invertible"
    end

    if opts.format == prodserver.mcp.WireEncoding.Invertible
        jsonData = prodserver.mcp.jsonrpc.mcpWireEncode(x);
    else
        jsonData = jsonencode(x);
    end

    writelines(jsonData,file);
end
