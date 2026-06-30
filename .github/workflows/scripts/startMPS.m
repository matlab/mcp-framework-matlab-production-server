function [cleanupMPS, cleanupDir, mps] = startMPS(options)
%startMPS Start a local MPS instance for integration testing.
%   [c1, c2, mps] = startMPS() starts MPS and sets env vars
%   MW_MCP_MPS_TEST_SERVER and MW_MCP_MPS_TEST_DATA_FOLDER.
%   Hold the returned cleanup handles to keep MPS alive.
%   Pass mps to runTests to capture logs on failure.
%
%   startMPS("persist", true) starts MPS without cleanup handles and
%   writes env vars to $GITHUB_ENV for use in subsequent workflow steps.
%   Use this mode when starting MPS in a run-command step before run-tests.

% Copyright 2026 The MathWorks, Inc.

    arguments
        options.persist (1,1) logical = false
    end

    toolsDir = fullfile(matlabroot, "test", "tools", "deployment");
    addpath(toolsDir);
    addpath(fullfile(toolsDir, "mps"));

    workDir = tempname;
    mkdir(workDir);

    dataFolder = fullfile(workDir, "data");
    mkdir(dataFolder);

    fprintf("Starting MPS instance in %s\n", workDir);
    mps = qeDeployMADSWebServer(workDir);
    mps.protocol = 'http';
    mps.mcrRoot = {matlabroot};
    mps.start();
    mps.updateConfigFile(mps.configFile,'enable-archive-management',true);
	mps.updateConfigFile(mps.configFile,'enable-metrics',true);
    mps.restart();

    serverUrl = regexprep(mps.getBrowserUrl(), '/$', '');
    fprintf("MPS started at %s\n", serverUrl);

    setenv("MW_MCP_MPS_TEST_SERVER", serverUrl);
    setenv("MW_MCP_MPS_TEST_DATA_FOLDER", dataFolder);

    % Poll health endpoint until server is ready
    healthUrl = serverUrl + "/api/health";
    maxWait = 60;
    elapsed = 0;
    ready = false;
    while elapsed < maxWait
        try
            resp = webread(healthUrl);
            if strcmp(resp.status, 'ok')
                ready = true;
                break;
            end
        catch
        end
        pause(2);
        elapsed = elapsed + 2;
    end
    assert(ready, "MPS failed to become healthy within %d seconds", maxWait);
    fprintf("MPS healthy after %d seconds\n", elapsed);

    if options.persist
        % Write env vars to $GITHUB_ENV so subsequent steps can access them
        ghEnvFile = getenv("GITHUB_ENV");
        if ~isempty(ghEnvFile)
            fid = fopen(ghEnvFile, "a");
            fprintf(fid, "MW_MCP_MPS_TEST_SERVER=%s\n", serverUrl);
            fprintf(fid, "MW_MCP_MPS_TEST_DATA_FOLDER=%s\n", dataFolder);
            fclose(fid);
            fprintf("Wrote env vars to GITHUB_ENV\n");
        end
        % No cleanup — MPS stays running for subsequent steps
        cleanupMPS = [];
        cleanupDir = [];
    else
        cleanupMPS = onCleanup(@() mps.stop());
        cleanupDir = onCleanup(@() rmdir(workDir, "s"));
    end
end
