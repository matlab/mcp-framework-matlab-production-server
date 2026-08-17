function classifyTest(tests)
%classifyTest Classify and run each test element sequentially.
%   Accepts a polymorphic vector of tests: function handles, file paths,
%   folder paths, or function/script names. Detects the type and runs each
%   appropriately.

% Copyright 2026 The MathWorks, Inc.

    if ~isa(tests, 'function_handle') && ~iscell(tests) && ...
            ~isstring(tests) && ~ischar(tests)
        error("prodserver:mcp:InvalidTestType", ...
            "tests must be a function handle, cell array, or string. " + ...
            "Got: %s", class(tests));
    end

    if isa(tests, 'function_handle')
        % Single function handle
        tests();
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
        t = tests(i);

        if isfolder(t)
            runtests(t);

        elseif endsWith(t, ".m")
            % File path ending in .m — verify existence, then determine type
            if exist(t, "file") ~= 2
                error("prodserver:mcp:TestFileNotFound", ...
                    "Test file '%s' not found.", t);
            end
            if isTestFile(t)
                runtests(t);
            else
                run(t);
            end

        else
            % Plain function or script name
            if exist(t, "file") == 2
                run(t);
            else
                error("prodserver:mcp:TestNotFound", ...
                    "Cannot find test '%s'.", t);
            end
        end
    end
end

function tf = isTestFile(filePath)
    % A file is treated as a test if its name starts with 't' or 'T' followed
    % by an uppercase letter (MathWorks test naming convention), or if it
    % contains a class inheriting from matlab.unittest.TestCase.
    [~, name] = fileparts(filePath);
    tf = strlength(name) > 1 && ...
        (startsWith(name, "t") || startsWith(name, "T")) && ...
        isstrprop(extractBetween(name, 2, 2), "upper");

    if ~tf
        % Check if file contains TestCase inheritance
        try
            txt = fileread(filePath);
            tf = contains(txt, "matlab.unittest.TestCase");
        catch
            tf = false;
        end
    end
end
