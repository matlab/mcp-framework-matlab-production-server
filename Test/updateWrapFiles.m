function updateWrapFiles(opts)
%updateWrapFiles Regenerate .wrap golden files from the current wrapper generator.
    arguments
        opts.action (1,1) string = "preview"
    end

    % Locate project folders relative to this function.
    testRoot = fileparts(mfilename("fullpath"));
    projectRoot = fileparts(testRoot);
    toyDir = fullfile(testRoot, "tools", "toyTools");
    paramDir = fullfile(testRoot, "tools", "parameterTools");

    % Temporarily add required folders to the path.
    oldPath = addpath(projectRoot, toyDir, paramDir);
    cleanup = onCleanup(@() path(oldPath));

    % Type map for tools that use non-standard MATLAB types.
    geomMap.geom = "double";

    % Manifest: one entry per .wrap file.
    manifest = [ ...
        entry("toyTools",      "toyToolOne",            geomMap)
        entry("toyTools",      "toyToolTwo",            geomMap)
        entry("toyTools",      "toyToolThree",          geomMap)
        entry("toyTools",      "toyFileSchema",         [])
        entry("parameterTools","threeFour",             [])
        entry("parameterTools","allInOptional",         [])
        entry("parameterTools","someInNVP",             [])
        entry("parameterTools","oneIndirectOutput",     [])
        entry("parameterTools","allIndirect",           [])
        entry("parameterTools","literalSchemas",        [])
    ];

    % UUID-style variable pattern (must match the test validation logic).
    varPattern = "v" + alphanumericsPattern ...
        + asManyOfPattern("_" + alphanumericsPattern, 4, 4);

    nUpdated = 0;
    nUnchanged = 0;

    for k = 1:numel(manifest)
        fcn  = manifest(k).fcn;
        tool = fcn + "MCP";
        wrapFile = fullfile(testRoot, "tools", ...
            manifest(k).folder, fcn + ".wrap");

        % Generate the wrapper code.
        extraOpts = {};
        if ~isempty(manifest(k).typemap)
            extraOpts = {"typemap", manifest(k).typemap};
        end
        code = prodserver.mcp.internal.mcpWrapper(fcn, tool, extraOpts{:});

        % Replace UUID variable with placeholder.
        marshalVars = unique(extract(code, varPattern));
        if ~isempty(marshalVars)
            code = replace(code, marshalVars(1), "!marshalVar");
        end

        % Compare with existing .wrap file.
        if isfile(wrapFile)
            old = strjoin(readlines(wrapFile), newline);
        else
            old = "";
        end

        if strcmp(code, old)
            nUnchanged = nUnchanged + 1;
            fprintf("  unchanged: %s\n", wrapFile);
        else
            nUpdated = nUpdated + 1;
            if strcmpi(opts.action,"preview")
                fprintf("  would update: %s\n", wrapFile);
            else
                writelines(code, wrapFile,TrailingLineEndingRule="never");
                fprintf("  updated: %s\n", wrapFile);
            end
        end
    end

    % Summary
    if strcmpi(opts.action,"preview")
        fprintf("\nDry run complete. %d would be updated, %d unchanged.\n", ...
            nUpdated, nUnchanged);
    else
        fprintf("\nDone. %d updated, %d unchanged.\n", nUpdated, nUnchanged);
    end
end

function e = entry(folder, fcn, typemap)
    e.folder = folder;
    e.fcn = string(fcn);
    e.typemap = typemap;
end
