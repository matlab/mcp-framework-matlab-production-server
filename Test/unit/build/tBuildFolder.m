classdef tBuildFolder < matlab.unittest.TestCase
% build makes its output folder if there is none, even when a MATLAB file
% or function of that name is on the path. It checked with exist, which is
% nonzero for those too, so folder="addOne" was never made while building
% addOne, and wrapForMCP failed: "These folders do not exist: 'addOne'".

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function inTemporaryFolder(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.CurrentFolderFixture
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            tmp = test.applyFixture(TemporaryFolderFixture);
            test.applyFixture(CurrentFolderFixture(tmp.Folder));
        end
    end

    methods (Test)

        function folderNamedLikeTheTool(test)
            tool = "toyScalarOne";
            test.assumeEqual(exist(tool, "file"), 2, "the tool is on the path");
            prodserver.mcp.build(tool, folder=tool, wrapper="None", ...
                stop="Definition");
            test.verifyTrue(isfolder(tool));
            test.verifyTrue(isfile(fullfile(tool, ...
                prodserver.mcp.MCPConstants.DefinitionFile)));
        end

        function aFileWhereTheFolderShouldBe(test)
            % A file of that name can't become the folder: say so.
            writelines("not a folder", "out");
            test.verifyError(@() prodserver.mcp.build("toyScalarOne", ...
                folder="out", wrapper="None", stop="Definition"), ...
                "prodserver:mcp:InaccessibleOutputFolder");
        end

    end
end
