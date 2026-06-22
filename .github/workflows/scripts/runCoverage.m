function runCoverage(suites, outputName)
%RUNCOVERAGE Run test suites with code coverage and post GitHub step summary.
%   runCoverage() runs all suites: unit, integration, and call.
%   runCoverage("unit") runs only unit tests.
%   runCoverage(["unit","integration","call"], "combined") runs everything.

% Copyright 2026 The MathWorks, Inc.

    if nargin < 1
        suites = ["unit", "integration", "call"];
    end
    if nargin < 2
        outputName = "";
    end

    import matlab.unittest.TestRunner
    import matlab.unittest.TestSuite
    import matlab.unittest.plugins.XMLPlugin
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat
    import matlab.unittest.plugins.codecoverage.CoverageReport

    scriptDir = fileparts(mfilename("fullpath"));
    baseDir = fileparts(fileparts(fileparts(scriptDir)));
    sourceDir = fullfile(baseDir, "+prodserver");
    testDir = fullfile(baseDir, "Test");
    if outputName == ""
        resultsDir = fullfile(baseDir, "coverage-results");
    else
        resultsDir = fullfile(baseDir, "coverage-results", outputName);
    end

    if ~isfolder(resultsDir)
        mkdir(resultsDir);
    end

    tests = matlab.unittest.Test.empty;

    if ismember("unit", suites)
        tests = [tests, TestSuite.fromFolder(...
            fullfile(testDir, "unit"), "IncludingSubfolders", true)];
    end

    if ismember("integration", suites)
        tests = [tests, TestSuite.fromFolder(...
            fullfile(testDir, "integration", "build"), "IncludingSubfolders", true)];
        tests = [tests, TestSuite.fromFolder(...
            fullfile(testDir, "integration", "client"), "IncludingSubfolders", true)];
    end

    mps = [];
    mpsCleanup = [];
    dirCleanup = [];
    if ismember("call", suites)
        [mpsCleanup, dirCleanup, mps] = startMPS(); %#ok<ASGLU>
        tests = [tests, TestSuite.fromFolder(...
            fullfile(testDir, "integration", "call"), "IncludingSubfolders", true)];
    end

    runner = TestRunner.withTextOutput;
    runner.addPlugin(XMLPlugin.producingJUnitFormat(...
        fullfile(resultsDir, "test-results.xml")));
    htmlDir = fullfile(resultsDir, "html");
    runner.addPlugin(CodeCoveragePlugin.forFolder(sourceDir, ...
        "IncludingSubfolders", true, ...
        "Producing", [CoberturaFormat(fullfile(resultsDir, "coverage.xml")), ...
                      CoverageReport(htmlDir)]));

    results = runner.run(tests);

    nTotal = numel(results);
    nPassed = nnz([results.Passed]);
    nFailed = nnz([results.Failed]);
    nIncomplete = nnz([results.Incomplete]);

    fprintf("\n%s\n", repmat('=', 1, 60));
    fprintf("COVERAGE RUN: %d total | %d passed | %d failed | %d incomplete\n", ...
        nTotal, nPassed, nFailed, nIncomplete);
    fprintf("%s\n", repmat('=', 1, 60));
    fprintf("Cobertura XML: %s\n", fullfile(resultsDir, "coverage.xml"));
    fprintf("HTML report:   %s\n\n", fullfile(htmlDir, "index.html"));

    if nFailed > 0 && ~isempty(mps)
        fprintf("===== MPS LOGS =====\n");
        mps.dispLogFiles();
        fprintf("===== END MPS LOGS =====\n\n");
    end

    writeStepSummary(suites, outputName, results, resultsDir);

    if nFailed > 0
        warning("prodserver:mcp:TestFailures", "%d test(s) failed.", nFailed);
    end
end

function writeStepSummary(suites, outputName, results, resultsDir)
    summaryFile = getenv("GITHUB_STEP_SUMMARY");
    if isempty(summaryFile)
        return
    end

    nTotal = numel(results);
    nPassed = nnz([results.Passed]);
    nFailed = nnz([results.Failed]);
    nIncomplete = nnz([results.Incomplete]);

    if outputName ~= ""
        title = outputName;
    else
        title = strjoin(suites, " + ");
    end

    if nFailed == 0
        badge = ":white_check_mark:";
    else
        badge = ":x:";
    end

    coberturaFile = fullfile(resultsDir, "coverage.xml");
    coveragePct = parseCoberturaRate(coberturaFile);

    fid = fopen(summaryFile, "a");
    if fid == -1
        return
    end
    fprintf(fid, "## %s Coverage %s\n\n", title, badge);
    if ~isnan(coveragePct)
        fprintf(fid, "**Line Coverage: %.1f%%**\n\n", coveragePct);
    end
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

function pct = parseCoberturaRate(coberturaFile)
    pct = nan;
    if ~isfile(coberturaFile)
        return
    end
    try
        txt = fileread(coberturaFile);
        tok = regexp(txt, 'line-rate="([^"]+)"', 'tokens', 'once');
        if ~isempty(tok)
            pct = str2double(tok{1}) * 100;
        end
    catch
    end
end
