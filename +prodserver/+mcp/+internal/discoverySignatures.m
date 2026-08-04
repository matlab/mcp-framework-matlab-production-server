function filePath = discoverySignatures(folder, archive)
%discoverySignatures Generate function signatures JSON for MPS /api/discovery.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    purpose = "Model Context Protocol entry point enabling AI agents to invoke MCP tools.";

    fcnName = "prodserver.mcp.internal.mcpHandler";

    entry.purpose = purpose;
    entry.inputs = { ...
        struct("name","request", "type",{{"struct"}}, ...
            "purpose","MCP JSON-RPC request") };
    entry.outputs = { ...
        struct("name","response", "type",{{"struct"}}, ...
            "purpose","MCP JSON-RPC response") };

    json = jsonencode(entry, PrettyPrint=true);

    % Build the full JSON manually because:
    %  - _schemaVersion is not a valid MATLAB struct field name
    %  - The function name contains dots, which are not valid field names
    schemaLine = sprintf('    "_schemaVersion": "%s"', MCPConstants.DiscoverySchemaVersion);
    fcnLine = sprintf('    "%s": %s', fcnName, json);
    json = sprintf('{\n%s,\n%s\n}', schemaLine, fcnLine);

    filePath = fullfile(folder, archive + "_functionSignatures.json");
    fid = fopen(filePath, "w");
    closeFile = onCleanup(@()fclose(fid));
    fwrite(fid, json);
end
