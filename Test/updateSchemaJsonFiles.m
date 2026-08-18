function updateSchemaJsonFiles(opts)
%updateSchemaJsonFiles Regenerate *_golden.json files for schema() no-block tests.
%   updateSchemaJsonFiles()               - Preview mode (dry run)
%   updateSchemaJsonFiles(action="write")  - Write golden files

% Copyright 2026 The MathWorks, Inc.

    arguments
        opts.action (1,1) string {mustBeMember(opts.action, ...
            ["preview","write"])} = "preview"
    end

    testRoot = fileparts(mfilename("fullpath"));
    projectRoot = fileparts(testRoot);
    schemaDir = fullfile(testRoot, "tools", "schemaTools");

    oldPath = addpath(projectRoot, schemaDir);
    restorePath = onCleanup(@() path(oldPath)); %#ok<NASGU>

    nUpdated = 0;
    nUnchanged = 0;

    % Each entry: {goldenFileName, functionName, exercises}
    entries = { ...
        "schemaComputeNoBlock_golden.json", "schemaComputeNoBlock", ...
            @() callWith(@schemaComputeNoBlock, 3, {1.0, 2.0, 3.0}); ...
        "schemaFlexNoBlockAll5_golden.json", "schemaFlexNoBlock", ...
            @() schemaFlexNoBlock(1,2,3,4,5); ...
        "schemaFlexNoBlock2of5_golden.json", "schemaFlexNoBlock", ...
            {@() schemaFlexNoBlock(1,2), @() schemaFlexNoBlock(1,2,3,4,5)}; ...
        "schemaVectorNoBlock_golden.json", "schemaVectorNoBlock", ...
            {@() callWith(@schemaVectorNoBlock, 3, {[1,2,3]}), ...
             @() callWith(@schemaVectorNoBlock, 3, {[1,2,3], 2.0})}; ...
        "schemaComplexNoBlock_golden.json", "schemaComplexNoBlock", ...
            @() callWith(@schemaComplexNoBlock, 3, {[3,0], [4,1]}); ...
        "schemaDatetimeNoBlock_golden.json", "schemaDatetimeNoBlock", ...
            @() callWith(@schemaDatetimeNoBlock, 3, {2026, 3, 15}); ...
        "schemaDurationNoBlock_golden.json", "schemaDurationNoBlock", ...
            @() callWith(@schemaDurationNoBlock, 2, {1, 30, 45}); ...
        "schemaTableNoBlock_golden.json", "schemaTableNoBlock", ...
            @() callWith(@schemaTableNoBlock, 2, {["A","B"], [1,2], "X"}); ...
        "schemaTimetableNoBlock_golden.json", "schemaTimetableNoBlock", ...
            @() callWith(@schemaTimetableNoBlock, 3, {[10,20,30], 9, 15}); ...
    };

    for k = 1:size(entries, 1)
        goldenFile = fullfile(schemaDir, entries{k,1});
        fcnName = entries{k,2};
        exercises = entries{k,3};

        defs = prodserver.mcp.schema(fcnName, exercises, ...
            encoding="Invertible");
        json = jsonencode(defs);

        [nUpdated, nUnchanged] = compareAndWrite( ...
            goldenFile, json, opts.action, nUpdated, nUnchanged);
    end

    if strcmpi(opts.action, "preview")
        fprintf("\nDry run complete. %d would be updated, %d unchanged.\n", ...
            nUpdated, nUnchanged);
    else
        fprintf("\nDone. %d updated, %d unchanged.\n", nUpdated, nUnchanged);
    end
end

function [nUpdated, nUnchanged] = compareAndWrite(jsonFile, json, ...
    action, nUpdated, nUnchanged)

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
        if strcmpi(action, "preview")
            fprintf("  would update: %s\n", jsonFile);
        else
            fid = fopen(jsonFile, "w");
            fwrite(fid, json);
            fclose(fid);
            fprintf("  updated: %s\n", jsonFile);
        end
    end
end

function callWith(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
