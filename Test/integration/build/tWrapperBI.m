classdef tWrapperBI < matlab.unittest.TestCase
% Experiment with various combinations of wrappers in the build stage.

    properties
        toolFolder
        tempFolder
    end

    methods(TestClassSetup)
        function initPath(test)
            import matlab.unittest.fixtures.PathFixture

            testFolder = fileparts(mfilename("fullpath"));
            test.toolFolder = fullfile(testFolder,"..","..","tools", ...
                "toyTools");
            % Add the tools folder to the path.
            test.applyFixture(PathFixture(test.toolFolder));
        end
    end

    methods(TestMethodSetup)

        function initTempFolder(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tfolder = TemporaryFolderFixture;
            applyFixture(test,tfolder);
            test.tempFolder = tfolder.Folder;
        end

    end

    methods (Test)
        function multiNone(test)

            fcn = ["toyScalarOne", "toyScalarTwo", "toyScalarFour"];
            wrapper = ["None", "None", "None"];
            % Generate wrappers and build -- only generate wrapper and
            % definition. Don't build the archive, because that takes a long
            % time.
            prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                wrapper=wrapper, stop="Definition");

            % No "*MCP.m" files in 'folder'
            d = dir(fullfile(test.tempFolder,"*MCP.m"));
            test.verifyEmpty(d,"Found *MCP.m files");

            % Tool files identical to fcn files. And all tools present.
            for n = 1:numel(fcn)
                tool = fullfile(test.tempFolder,fcn(n)+".m");
                test.verifyEqual(exist(tool,"file"),2,fcn(n));
                actual = readlines(tool);
                expected = readlines(which(fcn(n)));
                test.verifyEqual(actual,expected,fcn(n));
            end

        end
    end
end