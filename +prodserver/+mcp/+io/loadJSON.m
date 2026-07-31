function x = loadJSON(file, opts)
% loadJSON Load a MATLAB value from a JSON file.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        file string
        opts.format prodserver.mcp.WireEncoding = "Invertible"
    end

    fid = fopen(file);
    rawData = fread(fid, inf);
    jsonString = char(rawData');
    fclose(fid);
    j = jsondecode(jsonString);

    if opts.format == prodserver.mcp.WireEncoding.JSON
        x = j;
    else
        x = prodserver.mcp.jsonrpc.mcpWireDecodeValue(j);
    end

end
