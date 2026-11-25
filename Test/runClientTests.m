function results = runClientTests(opts)
%runClientTests Run the mock-server client tests, Test/integration/client,
%   in parallel.
%
%   results = runClientTests() runs them on a pool of 4 workers, which needs
%   Parallel Computing Toolbox, and prints a summary and any test that
%   didn't pass. results is the TestResult array.
%
%   results = runClientTests(workers=N) uses N workers, and workers=0
%   runs them in this MATLAB, one after another.
%
%   The tests can run at the same time: each class starts mock servers of
%   its own (MockCaller.startMcpServer), each on a free port, and the
%   parallel runner gives each worker whole classes. On 4 workers, 89
%   tests take about 260 s, pool start-up included. More workers gain
%   little: the longest classes, tDeployTransport and tArchiveWait, take
%   minutes by themselves, mostly waiting on purpose.

% Copyright 2026 The MathWorks, Inc.

    arguments
        opts.workers (1,1) double {mustBeInteger, mustBeNonnegative} = 4
    end

    here = fileparts(mfilename("fullpath"));
    root = fileparts(here);
    addpath(root);
    folder = fullfile(here, "integration", "client");
    suite = matlab.unittest.TestSuite.fromFolder(folder);
    runner = matlab.unittest.TestRunner.withTextOutput( ...
        OutputDetail=matlab.unittest.Verbosity.Terse);

    t = tic;
    if opts.workers > 0
        pool = gcp("nocreate");
        if isempty(pool) || pool.NumWorkers ~= opts.workers
            delete(pool);
            parpool(opts.workers);
        end
        % The workers need the framework and the mock-server helpers.
        spmd
            addpath(root);
            addpath(folder);
        end
        results = runInParallel(runner, suite);
    else
        results = run(runner, suite);
    end

    fprintf("\nClient tests: %d total, %d passed, %d failed, %d " + ...
        "incomplete, in %.0f s on %d worker(s)\n", numel(results), ...
        nnz([results.Passed]), nnz([results.Failed]), ...
        nnz([results.Incomplete]), toc(t), max(opts.workers, 1));
    for r = results(~[results.Passed])
        fprintf("  NOT PASSED: %s\n", r.Name);
    end
end
