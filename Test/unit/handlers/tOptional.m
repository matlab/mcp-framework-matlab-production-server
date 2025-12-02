classdef tOptional < matlab.unittest.TestCase

    properties
        toolsFolder
        request
        tempFolder
    end

    methods (TestClassSetup)

        function initTest(test)

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            % Make a temporary folder for output and put it on the path
            test.tempFolder = TemporaryFolderFixture;
            test.applyFixture(test.tempFolder);
            test.applyFixture(PathFixture(test.tempFolder.Folder));

            % Reuse the test functions in the definitions tests
            test.toolsFolder = fullfile(fileparts(mfilename("fullpath")), ...
                "..", "..", "tools", "toyTools");
            test.applyFixture(PathFixture(test.toolsFolder));

            test.request = struct(...
                'ApiVersion',[1 0 0], ...
                'Headers', {...
                {'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)';}}); 

        end
    end

    methods(Test)

      function optionalInputs(test)
            % Put the toy tools on the path
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(test.toolsFolder)); 

            td = prodserver.mcp.internal.mcpDefinition(...
                "toyScalarOptions", "toyScalarOptions");
            definition.tools = { td.tools };
            definition.signatures = { td.signatures };

            % Send definition round trip through JSON so it matches
            % expectedDefinition exactly.
            definition = jsondecode(jsonencode(definition));

        end

    end

end
