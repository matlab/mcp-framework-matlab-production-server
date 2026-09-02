function runTests(suite, resultsFile, folders, mps)
%RUNTESTS Run a test suite, write JUnit XML, and post GitHub step summary.
%   runTests('unit', 'test-results/unit.xml')
%   runTests('integration', 'test-results/int.xml', ["build","client"])
%   runTests('integration', 'test-results/call.xml', ["call"], mps)

% Copyright 2026 The MathWorks, Inc.

    import matlab.unittest.TestRunner
    import matlab.unittest.TestSuite
    import matlab.unittest.plugins.XMLPlugin

    if nargin < 4
        mps = [];
    end

    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(fileparts(fileparts(scriptDir)));
    baseFolder = fullfile(repoRoot, "Test", suite);
    assert(isfolder(baseFolder), "Test folder does not exist: %s", baseFolder);

    if nargin < 3 || isempty(folders)
        tests = TestSuite.fromFolder(baseFolder, "IncludingSubfolders", true);
    else
        tests = TestSuite.fromFolder( ...
            fullfile(baseFolder, folders(1)), "IncludingSubfolders", true);
        for f = folders(2:end)
            tests = [tests, TestSuite.fromFolder(...
                fullfile(baseFolder, f), "IncludingSubfolders", true)]; %#ok<AGROW>
        end
    end

    [resultsDir, ~, ~] = fileparts(resultsFile);
    if ~isfolder(resultsDir)
        mkdir(resultsDir);
    end

    runner = TestRunner.withTextOutput;
    runner.addPlugin(XMLPlugin.producingJUnitFormat(resultsFile));

    results = runner.run(tests);

    nTotal = numel(results);
    nPassed = nnz([results.Passed]);
    nFailed = nnz([results.Failed]);
    nIncomplete = nnz([results.Incomplete]);

    fprintf("\n%s\n", repmat('=', 1, 60));
    fprintf("TEST SUMMARY: %d total | %d passed | %d failed | %d incomplete\n", ...
        nTotal, nPassed, nFailed, nIncomplete);
    fprintf("%s\n\n", repmat('=', 1, 60));

    if nFailed > 0
        failedIdx = find([results.Failed]);
        fprintf("Failed tests:\n");
        for i = failedIdx
            fprintf("  FAIL: %s\n", results(i).Name);
        end
        fprintf("\n");

        if ~isempty(mps)
            fprintf("===== MPS LOGS =====\n");
            mps.dispLogFiles();
            fprintf("===== END MPS LOGS =====\n\n");

            if isfolder(mps.logsDir)
                mpsLogDir = fullfile(resultsDir, "mps-logs");
                if ~isfolder(mpsLogDir)
                    mkdir(mpsLogDir);
                end
                copyfile(fullfile(mps.logsDir, '*'), mpsLogDir);
            end
        end
    end

    writeStepSummary(suite, folders, results);

    assert(nFailed == 0, "%d test(s) failed.", nFailed);
end

function writeStepSummary(suite, folders, results)
    summaryFile = getenv("GITHUB_STEP_SUMMARY");
    if isempty(summaryFile)
        return
    end

    nTotal = numel(results);
    nPassed = nnz([results.Passed]);
    nFailed = nnz([results.Failed]);
    nIncomplete = nnz([results.Incomplete]);

    if nargin >= 2 && ~isempty(folders)
        title = suite + " (" + strjoin(folders, ", ") + ")";
    else
        title = suite;
    end

    if nFailed == 0
        badge = ":white_check_mark:";
    else
        badge = ":x:";
    end

    fid = fopen(summaryFile, "a");
    if fid == -1
        return
    end
    fprintf(fid, "## %s Test Results %s\n\n", title, badge);
    fprintf(fid, "| Total | Passed | Failed | Incomplete |\n");
    fprintf(fid, "|-------|--------|--------|------------|\n");
    fprintf(fid, "| %d | %d | %d | %d |\n\n", nTotal, nPassed, nFailed, nIncomplete);

    if nFailed > 0
        fprintf(fid, "<details><summary>Failed Tests</summary>\n\n");
        failedIdx = find([results.Failed]);
        for i = failedIdx
            fprintf(fid, "- `%s`\n", results(i).Name);
        end
        fprintf(fid, "\n</details>\n\n");
    end
    fclose(fid);
end
