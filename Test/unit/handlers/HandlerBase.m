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

            test.request = struct(...
                'ApiVersion',[1 0 0], ...
                'Headers', {...
                {'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)';}}); 
        end
    end

    methods
        function defineTools(test,fcns,tools,dFiles)
            import prodserver.mcp.MCPConstants

            % Definition generation support in 26a and later.
            if nargin > 3
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
                    tools, fcns);
            end

            test.definitionFile = fullfile(test.tempFolder.Folder,...
                MCPConstants.DefinitionFile);
            def.(MCPConstants.DefinitionVariable) = definition;
            save(test.definitionFile,"-struct","def");

        end
    end
end