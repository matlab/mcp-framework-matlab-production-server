classdef tWalkthroughs < matlab.unittest.TestCase
% Dynamic integration test: discover and run all example walkthroughs.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        example
    end

    properties
        server
        repoRoot
    end

    methods (Static, TestParameterDefinition)

        function example = discoverExamples()
            thisFile = mfilename("fullpath");
            repoRoot = fullfile(fileparts(thisFile), "..", "..");
            examplesRoot = fullfile(repoRoot, "Examples");

            entries = dir(fullfile(examplesRoot, "*", "walkthrough.m"));
            skip = ["MATLABOpenAI", "DevAndTest"];

            example = struct();
            for k = 1:numel(entries)
                folder = entries(k).folder;
                [~, name] = fileparts(folder);
                if ismember(name, skip)
                    continue
                end
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

    end

    methods (Test)

        function runWalkthrough(test, example)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.CurrentFolderFixture
            import matlab.unittest.fixtures.PathFixture

            % Clean up deployed archives after this test
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, example.archives));

            % Copy example contents into a temporary folder
            tmp = test.applyFixture(TemporaryFolderFixture);
            copyfile(fullfile(example.folder, "*"), tmp.Folder);
            test.applyFixture(CurrentFolderFixture(tmp.Folder));
            test.applyFixture(PathFixture(tmp.Folder));

            % Close any figures opened during the walkthrough
            cleanup = onCleanup(@() close("all"));

            % Inject mpsServer and run the walkthrough script
            t = tic;
            mpsServer = test.server; %#ok<NASGU>
            run(fullfile(tmp.Folder, "walkthrough.m"));

            fprintf(1,"%s took %.2f seconds\n",example.name,...
                round(toc(t),2));
        end

    end

    methods (Static, Access=private)

        function archives = archivesForExample(name)
            switch name
                case "PrincipalStress"
                    archives = "principalStress";
                case "Primes"
                    archives = "primeSequence";
                case "Periodic Noise"
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

    end

end
