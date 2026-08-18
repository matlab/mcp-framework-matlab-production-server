function classifyTest(tests)
%classifyTest Classify and run each test element sequentially.
%   Accepts a polymorphic vector of tests: function handles, file paths,
%   folder paths, or function/script names. Detects the type and runs each
%   appropriately.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        tests { prodserver.mcp.validation.mustBeTestSpecification }
    end

    if isa(tests, 'function_handle')
        % Single function handle
        try
            tests();
        catch me
            error("prodserver:mcp:TestFcnFailed", ...
                "Cannot generate tool description. Test function " + ...
                "%s failed: %s.", func2str(tests), me.message); 
        end
        return;
    end

    if iscell(tests)
        for i = 1:numel(tests)
            prodserver.mcp.internal.classifyTest(tests{i});
        end
        return;
    end

    % String vector — classify each element
    for i = 1:numel(tests)
        t = string(tests(i));
        t = strrep(t, '\', '/');

        if isfolder(t)
            results = runtests(t,OutputDetail="None");
            failed = sum([results.Failed]);
            if failed ~= 0
                error("prodserver:mcp:TestSuiteFailed", ...
                    "Cannot generate tool description. Test suite in " + ...
                    "%s has %d failure(s).", t, failed);
            end

        else
            if exist(t, "file") ~= 2
                error("prodserver:mcp:TestFileNotFound", ...
                    "Test file '%s' not found.", t);
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
                error("prodserver:mcp:TestFileFailed", ...
                    "Cannot generate tool description. Test file " + ...
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
