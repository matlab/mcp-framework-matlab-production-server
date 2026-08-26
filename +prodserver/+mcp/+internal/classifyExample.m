function classifyExample(example)
%classifyExample Classify and run each example element sequentially.
%   Accepts a polymorphic vector of examples: function handles, file paths,
%   folder paths, or function/script names. Detects the type and runs each
%   appropriately.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        example { prodserver.mcp.validation.mustBeExampleSpecification }
    end

    if isa(example, 'function_handle')
        % Single function handle
        try
            example();
        catch me
            error("prodserver:mcp:ExampleFcnFailed", ...
                "Cannot generate tool description. Example function " + ...
                "%s failed: %s.", func2str(example), me.message);
        end
        return;
    end

    if iscell(example)
        for i = 1:numel(example)
            prodserver.mcp.internal.classifyExample(example{i});
        end
        return;
    end

    % String vector — classify each element
    for i = 1:numel(example)
        t = string(example(i));
        t = strrep(t, '\', '/');

        if isfolder(t)
            results = runtests(t,OutputDetail="None");
            failed = sum([results.Failed]);
            if failed ~= 0
                error("prodserver:mcp:ExampleSuiteFailed", ...
                    "Cannot generate tool description. Example suite in " + ...
                    "%s has %d failure(s).", t, failed);
            end

        else
            if exist(t, "file") ~= 2
                error("prodserver:mcp:ExampleFileNotFound", ...
                    "Example file '%s' not found.", t);
            end
            isTest = isTestFile(t);
            if isTest
                results = runtests(t,OutputDetail="None");
                failed = sum([results.Failed]);
            else
                try
                    run(t);
                    failed = 0;
                catch me
                    failed = 1;
                end
            end
            if failed ~= 0
                error("prodserver:mcp:ExampleFileFailed", ...
                    "Cannot generate tool description. Example file " + ...
                    "%s has %d failure(s).", t, failed);
            end
        end
    end
end

function tf = isTestFile(filePath)

    filePath = strrep(filePath, '\', '/');
    [folder, className] = fileparts(filePath);

    p = path;
    restorePath = onCleanup(@() path(p));

    parts = split(folder, '/');
    pkgIdx = find(startsWith(parts, "+"), 1, 'first');
    if ~isempty(pkgIdx)
        folder = strjoin(parts(1:pkgIdx-1), "/");
        pkgParts = erase(parts(pkgIdx:end), "+");
        className = strjoin([pkgParts; string(className)], ".");
    end

    addpath(folder);
    s = superclasses(className);

    tf = any(strcmp(s, 'matlab.unittest.TestCase'));
end
