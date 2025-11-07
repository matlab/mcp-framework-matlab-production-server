classdef HandlerBase < matlab.unittest.TestCase
    properties
        exampleFolder
        request
        tempFolder
        definitionFile
        toolNames
        fcnNames
    end

    methods (TestClassSetup)

        function initTest(test)
            import prodserver.mcp.MCPConstants

            testFolder = fileparts(mfilename("fullpath"));
            test.exampleFolder = fullfile(testFolder,"..","..","..","Examples");

            % Put the earthquake and signal example folders on the path.
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(fullfile(test.exampleFolder,...
                "Earthquake")));
            test.applyFixture(PathFixture(fullfile(test.exampleFolder,...
                "Primes")));

            % Make a temporary folder for output and put it on the path
            import matlab.unittest.fixtures.TemporaryFolderFixture
            test.tempFolder = TemporaryFolderFixture;
            test.applyFixture(test.tempFolder);
            test.applyFixture(PathFixture(test.tempFolder.Folder));

            % Assume defineForMCP is working. It has its own tests. :-)
            % Better decoupling requires a lot of (probably unnecessary)
            % work.
            test.fcnNames = ["plotTrajectoriesMCP","primeSequence"];
            test.toolNames = ["plotTrajectories","primeSequence"];
            definition = prodserver.mcp.internal.defineForMCP(...
                test.toolNames, test.fcnNames, [],[],[]);
            test.definitionFile = fullfile(test.tempFolder.Folder,...
                MCPConstants.DefinitionFile);
            def.(MCPConstants.DefinitionVariable) = definition;
            save(test.definitionFile,"-struct","def");

            test.request = struct(...
                'ApiVersion',[1 0 0], ...
                'Headers', {...
                {'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)';}}); ...

        end

    end
end