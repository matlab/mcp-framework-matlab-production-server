function x = loadJSON(file, opts)
% loadJSON Load a MATLAB value from a JSON file.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        file string
        opts.format prodserver.mcp.WireEncoding = "Invertible"
    end

    % JSON is UTF-8 (RFC 8259), and saveJSON writes UTF-8. readUTF8 also
    % keeps characters fileread loses, and drops a byte order mark, which
    % jsondecode rejects.
    j = jsondecode(prodserver.mcp.internal.readUTF8(file));
    decoded = prodserver.mcp.jsonrpc.mcpDecode(opts.format, j);
    x = decoded{1};
end
