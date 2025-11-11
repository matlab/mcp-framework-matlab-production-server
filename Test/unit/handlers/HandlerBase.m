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

            earthquakeFolder = fullfile(test.exampleFolder,...
                "Earthquake");
            test.applyFixture(PathFixture(earthquakeFolder));

            primeFolder = fullfile(test.exampleFolder,"Primes");
            test.applyFixture(PathFixture(primeFolder));

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

            % Definition generation support in 26a and later.
            if isMATLABReleaseOlderThan("R2026a")
                dFiles = [ ...
                    fullfile(earthquakeFolder,"plotTrajectories.json"), ...
                    fullfile(primeFolder,"primeSequence.json"), ...
                    ];
                dJSON = arrayfun(@(f)jsondecode(fileread(f)),dFiles, ...
                    UniformOutput=false);
                definition.tools = cell(1,numel(dJSON));
                for n = 1:numel(dJSON)
                    td = dJSON{n};
                    definition.tools{n} = td.tools;
                    for f = string(fieldnames(td.signatures))'
                        definition.signatures.(f) = td.signatures.(f);
                    end
                end
            else
                definition = prodserver.mcp.internal.defineForMCP(...
                    test.toolNames, test.fcnNames);
            end

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