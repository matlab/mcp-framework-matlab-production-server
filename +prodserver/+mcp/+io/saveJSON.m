function saveJSON(file,x,opts)
% saveJSON Save x to file in JSON.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        file string
        x
        opts.format prodserver.mcp.WireEncoding = "Invertible"
    end

    % The same encoding a tool's output gets.
    encoded = prodserver.mcp.jsonrpc.mcpEncode(opts.format, x);
    jsonData = jsonencode(encoded{1});

    % writeUTF8, not writelines, which loses characters outside the Basic
    % Multilingual Plane.
    prodserver.mcp.internal.writeUTF8(file, jsonData);
end
