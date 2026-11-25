classdef tWalkthroughs < matlab.unittest.TestCase
% Dynamic integration test: discover and run all example walkthroughs, then
% test what each one deployed.
%
%   Each example's walkthrough runs once, in class setup, and its archives
%   stay deployed for the example's tests:
%
%     tDeployed   every archive answers ping and lists its tools
%     tHasPrompt  the walkthrough suggests a prompt to try in an MCP client
%     tPrompt     an agent given each of those prompts calls the example's
%                 tools, and none of the calls fails. Needs devai, so CI
%                 skips it.
%
%   tPrompt runs Claude, Gemini and Codex. To run one, filter by its name:
%
%     runtests("Test/examples/tWalkthroughs.m", ParameterName="claude")

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        example
    end

    properties (TestParameter)
        agent = struct( ...
            "claude", @prodserver.mcp.test.mixin.ClaudeAgent, ...
            "gemini", @prodserver.mcp.test.mixin.GeminiAgent, ...
            "codex", @prodserver.mcp.test.mixin.CodexAgent)
    end

    properties
        server
        repoRoot
        archives        % the example's archives, which are its MCP servers
        endpoints       % and their URLs
        prompts         % the prompts its walkthrough suggests
        workFolder      % the copy of the example the walkthrough ran in
    end

    methods (Static, TestParameterDefinition)

        function example = discoverExamples()
            thisFile = mfilename("fullpath");
            repoRoot = fullfile(fileparts(thisFile), "..", "..");
            examplesRoot = fullfile(repoRoot, "Examples");

            entries = dir(fullfile(examplesRoot, "*", "walkthrough.m"));

            example = struct();
            for k = 1:numel(entries)
                folder = entries(k).folder;
                [~, name] = fileparts(folder);
                key = matlab.lang.makeValidName(name);
                example.(key) = struct( ...
                    'folder', folder, ...
                    'name', name, ...
                    'archives', tWalkthroughs.archivesForExample(name));
            end
        end

    end

    methods (TestClassSetup)

        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture
            thisFile = mfilename("fullpath");
            test.repoRoot = fullfile(fileparts(thisFile), "..", "..");
            test.applyFixture(PathFixture(test.repoRoot));
        end

        function requireActiveServer(test)
            test.server = getenv(prodserver.mcp.MCPConstants.TestServerEnvVar);
            test.assertTrue(~isempty(test.server), ...
                "Set environment variable " + ...
                prodserver.mcp.MCPConstants.TestServerEnvVar + ...
                " to network address of MPS instance for testing.");

            healthQuery = test.server + "/api/health";
            response = webread(healthQuery);
            test.assertTrue(strcmp(response.status, "ok"), ...
                "Invalid response to health query: " + response.status);
        end

        function runWalkthrough(test, example)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.CurrentFolderFixture
            import matlab.unittest.fixtures.PathFixture

            reason = tWalkthroughs.skipReason(example.name);
            test.assumeTrue(reason == "", "The " + example.name + ...
                " walkthrough doesn't run here: " + reason);

            test.archives = example.archives;
            test.endpoints = test.server + "/" + example.archives + "/mcp";
            test.prompts = tWalkthroughs.promptsIn( ...
                fullfile(example.folder, "walkthrough.m"));

            % Clean up deployed archives after this example's tests
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, example.archives));

            % Copy example contents into a temporary folder
            tmp = test.applyFixture(TemporaryFolderFixture);
            copyfile(fullfile(example.folder, "*"), tmp.Folder);
            test.applyFixture(CurrentFolderFixture(tmp.Folder));
            test.applyFixture(PathFixture(tmp.Folder));
            test.workFolder = tmp.Folder;

            % Close any figures opened during the walkthrough
            cleanup = onCleanup(@() close("all"));

            % Special case for MultiTool, which renders a dense image --
            % machines that lack hardware acceleration can take over an
            % hour to render a 200,000 point scatter plot. So reduce number
            % of points to something any machine can render. The point of
            % the test is to validate the code path, after all. There is
            % code in the MultiTool walkthrough that allows N to be
            % overridden.
            if strcmpi(example.name,"MultiTool")
                ri = rendererinfo
                ri.Details
                if strcmpi(ri.Details.HardwareSupportLevel, 'None')
                    N = 1000; %#ok<NASGU>
                end
            end

            % SignalFilterApp builds its view with Node.js, and the npm
            % toolchain is in Examples/package.json, which isn't copied here.
            % The walkthrough builds the view only if it's missing, so a
            % stand-in view lets its MATLAB steps run without Node.js.
            if example.name == "SignalFilterApp"
                view = fullfile(tmp.Folder, "app", "dist", "mcp-app.html");
                mkdir(fileparts(view));
                writelines("<!DOCTYPE html><html><body>Stand-in view</body></html>", view);
            end

            % Inject mpsServer and run the walkthrough script. An error
            % here fails every test of this example, so name the
            % walkthrough that broke.
            t = tic;
            mpsServer = test.server; %#ok<NASGU>
            try
                run(fullfile(tmp.Folder, "walkthrough.m"));
            catch me
                test.assertFail("The " + example.name + ...
                    " walkthrough failed: " + ...
                    me.getReport("extended", "hyperlinks", "off"));
            end

            fprintf(1,"%s took %.2f seconds\n",example.name,...
                round(toc(t),2));
        end

    end

    methods (Test)

        function tDeployed(test)
            test.assertNotEmpty(test.archives, ...
                "Add the example's archives to tWalkthroughs.archivesForExample.");
            for endpoint = test.endpoints
                test.verifyTrue(prodserver.mcp.ping(endpoint), ...
                    endpoint + " should answer ping.");
                test.verifyNotEmpty(prodserver.mcp.list(endpoint, "Tool"), ...
                    endpoint + " should list its tools.");
            end
        end

        function tHasPrompt(test)
            test.verifyNotEmpty(test.prompts, ...
                "walkthrough.m should suggest a prompt, in indented " + ...
                "comment lines after ""try this prompt:"".");
        end

        function tPrompt(test, agent)
            test.assumeTrue(prodserver.mcp.test.mixin.AgentFixture.available(), ...
                "devai is not available on PATH.");
            fix = test.applyFixture(agent(test.archives, test.endpoints, ...
                Folder=test.workFolder));

            % An agent's choices vary from run to run, so a prompt gets a
            % second try before it fails.
            for prompt = test.prompts
                problem = tWalkthroughs.tryPrompt(fix, prompt);
                if problem ~= ""
                    problem = tWalkthroughs.tryPrompt(fix, prompt);
                end
                test.verifyEqual(problem, "", "Prompt: " + prompt);
            end
        end

    end

    methods (Static, Access=private)

        function archives = archivesForExample(name)
            switch name
                case "PrincipalStress"
                    archives = "principalStress";
                case "Primes"
                    archives = "primeSequence";
                case {"Periodic Noise", "SignalFilterApp"}
                    archives = "cleanSignal";
                case "Earthquake"
                    archives = "plotTrajectories";
                case "Materials"
                    archives = "Materials";
                case "StructuredData"
                    archives = ["Circles", "BeamAnalysis"];
                case "MultiTool"
                    archives = "Fractalizer";
                case "WireEncoding"
                    archives = "WireEncoding";
                otherwise
                    archives = string.empty;
            end
        end

        function reason = skipReason(name)
        %skipReason Why the walkthrough for example NAME can't run here, or
        %   "" if it can.
            onCI = getenv("GITHUB_ACTIONS") == "true";
            switch name
                case "MATLABOpenAI"
                    reason = "It needs an OpenAI API key.";
                case "DevAndTest"
                    reason = "It opens productionServerArchiveCompiler, " + ...
                        "an interactive app.";
                case "Earthquake"
                    % plotTrajectories exports a figure via saveas, which
                    % fails in the CI MATLAB build (figure export error
                    % "getExportCaps is not a function"), even for a
                    % trivial plot.
                    reason = "";
                    if onCI
                        reason = "Figure export fails in the CI MATLAB build.";
                    end
                case "MultiTool"
                    % Even 1,000 points stalls on the GLNXA64 architecture
                    % in the CI pipeline.
                    reason = "";
                    if onCI
                        reason = "Rendering its fractal stalls in CI.";
                    end
                otherwise
                    reason = "";
            end
        end

        function prompts = promptsIn(file)
        %promptsIn The prompts a walkthrough suggests: the indented comment
        %   lines after "try this prompt:", one prompt per paragraph. The
        %   first line that is neither indented nor a blank comment ends
        %   them.
            lines = readlines(file);
            start = find(contains(lines, "try this prompt:"), 1);
            prompts = string.empty;
            if isempty(start)
                return
            end
            current = "";
            for line = lines(start+1:end)'
                if startsWith(line, "%   ")
                    current = strjoin([current, strtrim(extractAfter(line, 1))]);
                elseif strtrim(line) == "%"
                    if strtrim(current) ~= ""
                        prompts(end+1) = strtrim(current); %#ok<AGROW>
                    end
                    current = "";
                else
                    break
                end
            end
            if strtrim(current) ~= ""
                prompts(end+1) = strtrim(current);
            end
        end

        function problem = tryPrompt(fix, prompt)
        %tryPrompt Give the agent PROMPT. Return what went wrong, or "": a
        %   call to the example's tools that failed, or no call at all.
        %   An agent that answers from what it knows, or does the work
        %   itself, hasn't tested the tools.
            result = fix.run(prompt + " Use the MCP server tools to do this.");
            calls = result.calls;
            if isempty(calls)
                problem = "The agent called none of the tools on " + ...
                    strjoin(fix.Servers, ", ") + ". It answered: " + ...
                    result.answer;
                return
            end
            failed = calls([calls.failed]);
            problem = "";
            if ~isempty(failed)
                problem = strjoin(compose("%s/%s failed: %s", ...
                    [failed.server]', [failed.tool]', [failed.error]'), newline);
            end
        end

    end

end
