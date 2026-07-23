function updateToyJsonFiles(opts)
%updateToyJsonFiles Regenerate toy*.json golden files from the current definition generator.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        opts.action (1,1) string = "preview"
    end

    import prodserver.mcp.MCPConstants

    % Locate project folders relative to this function.
    testRoot = fileparts(mfilename("fullpath"));
    projectRoot = fileparts(testRoot);
    toyDir = fullfile(testRoot, "tools", "toyTools");

    % Temporarily add required folders to the path.
    oldPath = addpath(projectRoot, toyDir);
    restorePath = onCleanup(@() path(oldPath));

    % Temporary folder for wrapper generation.
    tmpDir = string(tempname);
    mkdir(tmpDir);
    addpath(tmpDir);
    removeTmp = onCleanup(@() rmdir(tmpDir, "s"));

    nUpdated = 0;
    nUnchanged = 0;

    % --- Simple single-tool definitions ---
    % defineForMCP(tool, tool) → jsonencode(td.tools{1})
    simpleTools = ["toyZeroInputs", "toyZeroOutputs", "toyScalarOptions", ...
        "toyScalarNVOptions", "toyFileSchema", "toyLiteralLimit"];

    for k = 1:numel(simpleTools)
        tool = simpleTools(k);
        td = prodserver.mcp.internal.defineForMCP(tool, tool);
        json = jsonencode(td.tools{1});
        [nUpdated, nUnchanged] = compareAndWrite( ...
            fullfile(toyDir, tool + ".json"), json, ...
            opts.action, nUpdated, nUnchanged);
    end

    % --- Multi-tool definition (toyTools.json) ---
    % defineForMCP with three tools and typemap, wrapped in {tools, signatures}
    % and sent through a JSON round-trip.
    tools = ["toyToolOne", "toyToolTwo", "toyToolThree"];
    typemap.geom = "double";
    td = prodserver.mcp.internal.defineForMCP(tools, tools, typemap=typemap);
    definition.tools = td.tools;
    definition.signatures = td.signatures;
    definition = jsondecode(jsonencode(definition));
    json = jsonencode(definition);
    [nUpdated, nUnchanged] = compareAndWrite( ...
        fullfile(toyDir, "toyTools.json"), json, ...
        opts.action, nUpdated, nUnchanged);

    % --- Wrapper-based definition (toyURLOptionsMCP.json) ---
    % Generate the wrapper with import options, then define from the wrapper.
    fcn = "toyURLOptions";
    
    % Import options for string matrix files
    iOpts = delimitedTextImportOptions(DataLines=1,...
        ImportErrorRule="error");
    importFields = ["ngc", "constellation", "messier", "name"];

    prodserver.mcp.internal.wrapForMCP(fcn, "", tmpDir, ...
        import=importFields);
    rehash
    wrapperTool = fcn + MCPConstants.WrapperFileSuffix;
    td = prodserver.mcp.internal.defineForMCP(fcn, wrapperTool);
    json = jsonencode(td.tools{1});
    [nUpdated, nUnchanged] = compareAndWrite( ...
        fullfile(toyDir, wrapperTool + ".json"), json, ...
        opts.action, nUpdated, nUnchanged);

    % --- Defs structure (toyFileSchemaDefs.json) ---
    % Second return value of wrapForMCP for toyFileSchema.
    [~, def] = prodserver.mcp.internal.wrapForMCP("toyFileSchema", "", tmpDir);
    json = jsonencode(def{1});
    [nUpdated, nUnchanged] = compareAndWrite( ...
        fullfile(toyDir, "toyFileSchemaDefs.json"), json, ...
        opts.action, nUpdated, nUnchanged);

    % Summary
    if strcmpi(opts.action,"preview")
        fprintf("\nDry run complete. %d would be updated, %d unchanged.\n", ...
            nUpdated, nUnchanged);
    else
        fprintf("\nDone. %d updated, %d unchanged.\n", nUpdated, nUnchanged);
    end
end

function [nUpdated, nUnchanged] = compareAndWrite(jsonFile, json, action, nUpdated, nUnchanged)
    if isfile(jsonFile)
        old = strtrim(fileread(jsonFile));
    else
        old = "";
    end

    if strcmp(json, old)
        nUnchanged = nUnchanged + 1;
        fprintf("  unchanged: %s\n", jsonFile);
    else
        nUpdated = nUpdated + 1;
        if strcmpi(action,"preview")
            fprintf("  would update: %s\n", jsonFile);
        else
            fid = fopen(jsonFile, "w");
            fwrite(fid, json);
            fclose(fid);
            fprintf("  updated: %s\n", jsonFile);
        end
    end
end
