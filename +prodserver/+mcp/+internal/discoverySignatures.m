function filePath = discoverySignatures(folder, archive)
%discoverySignatures Generate function signatures JSON for MPS /api/discovery.
%
%   Uses compiler.internal.ui.generateFunctionSignaturesTemplate to produce
%   the base JSON, then injects "purpose" fields for the function, its
%   inputs, and its outputs.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    fcnFile = which("prodserver.mcp.internal.mcpHandler");
    raw = compiler.internal.ui.generateFunctionSignaturesTemplate(fcnFile);

    % Strip // comment lines produced by the template generator.
    lines = splitlines(raw);
    lines = lines(~startsWith(strtrim(lines), "//"));
    json = strjoin(lines, newline);

    % The top-level keys (_schemaVersion, dotted function name) are not
    % valid MATLAB field names, so extract the function entry by finding
    % its brace-delimited object, decode that, manipulate, re-encode.
    fcnName = "prodserver.mcp.internal.mcpHandler";
    json = char(json);
    startIdx = strfind(json, sprintf('"%s"', fcnName));
    colonIdx = strfind(json(startIdx:end), ':') + startIdx - 1;
    objStart = colonIdx(1);
    entry = jsondecode(extractBetweenBraces(json, objStart));

    % Set the function-level purpose.
    entry.purpose = "Model Context Protocol entry point enabling AI agents to invoke MCP tools.";

    % Set per-parameter purpose and type.
    paramPurpose = struct("request","MCP JSON-RPC request", ...
        "response","MCP JSON-RPC response");
    entry.inputs = fixParams(entry.inputs, paramPurpose);
    entry.outputs = fixParams(entry.outputs, paramPurpose);

    % Wrap inputs/outputs in cell arrays so jsonencode produces JSON arrays
    % even when there is only one element.
    if ~iscell(entry.inputs)
        entry.inputs = num2cell(entry.inputs);
    end
    if ~iscell(entry.outputs)
        entry.outputs = num2cell(entry.outputs);
    end

    % Re-encode the entry and assemble final JSON with the keys that
    % can't be represented as struct field names.
    entryJson = jsonencode(entry, PrettyPrint=true);
    entryJson = "    " + replace(string(entryJson), newline, newline + "    ");
    schemaLine = sprintf('    "_schemaVersion": "%s"', ...
        MCPConstants.SignatureSchemaVersion);
    fcnLine = sprintf('    "%s": %s', fcnName, entryJson);
    json = sprintf('{\n%s,\n%s\n}', schemaLine, fcnLine);

    filePath = fullfile(folder, archive + "_functionSignatures.json");
    fid = fopen(filePath, "w");
    if fid == -1
        error("prodserver:mcp:CannotWriteDiscovery", ...
            "Cannot write discovery signatures to '%s'.", filePath);
    end
    closeFile = onCleanup(@()fclose(fid));
    fwrite(fid, json);
end

function params = fixParams(params, purposeMap)
    for k = 1:numel(params)
        p = params(k);
        if isfield(purposeMap, p.name)
            p.purpose = purposeMap.(p.name);
        end
        p.type = "struct";
        params(k) = p;
    end
end

function s = extractBetweenBraces(txt, startFrom)
    depth = 0;
    first = 0;
    for i = startFrom:numel(txt)
        c = txt(i);
        if c == '{'
            if depth == 0, first = i; end
            depth = depth + 1;
        elseif c == '}'
            depth = depth - 1;
            if depth == 0
                s = txt(first:i);
                return
            end
        end
    end
    s = txt(first:end);
end
