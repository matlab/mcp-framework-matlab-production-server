classdef tAutoWrapper < matlab.unittest.TestCase
%tAutoWrapper Tests for wrapper="Auto" behavior.

% Copyright 2026 The MathWorks, Inc.

    properties
        toolFolder
        tempFolder
    end

    methods (TestClassSetup)

        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end

        function initPath(test)
            import matlab.unittest.fixtures.PathFixture
            test.toolFolder = fullfile(fileparts(mfilename("fullpath")),...
                "..", "..", "tools","toyTools");
            test.applyFixture(PathFixture(test.toolFolder));
        end
    end

    methods (TestMethodSetup)

        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
        end

    end

    methods (Test)

        function autoSkipsWrapperForScalarTool(test)
            % toyScalarOne has all (1,1) parameters — Auto should skip.
            import prodserver.mcp.MCPConstants
            [wrappers,indirect] = prodserver.mcp.internal.wrapForMCP(...
                "toyScalarOne", MCPConstants.AutoWrapper, test.tempFolder);

            % Should copy the original function, not generate a wrapper.
            [~,file] = fileparts(wrappers);
            test.verifyEqual(file, "toyScalarOne");
            test.verifyTrue(isfile(wrappers));
            test.verifyTrue(isempty(indirect{1}));
        end

        function autoGeneratesWrapperForLargeTool(test)
            % toyToolOne has unbounded b (uint64 no size) — needs wrapper.
            import prodserver.mcp.MCPConstants
            [wrappers,indirect] = prodserver.mcp.internal.wrapForMCP(...
                "toyToolOne", MCPConstants.AutoWrapper, test.tempFolder);

            [~,file] = fileparts(wrappers);
            test.verifyEqual(file, "toyToolOneMCP");
            test.verifyTrue(isfile(wrappers));
            test.verifyFalse(isempty(indirect{1}));
        end

        function autoIsDefaultBehavior(test)
            % The default wrapper in build.m is "Auto". Verify that
            % wrapForMCP produces the same result for "Auto" and the
            % default.
            import prodserver.mcp.MCPConstants
            [w1,~] = prodserver.mcp.internal.wrapForMCP(...
                "toyScalarOne", MCPConstants.AutoWrapper, test.tempFolder);
            [~,f1] = fileparts(w1);
            test.verifyEqual(f1, "toyScalarOne");
        end

        function noneAlwaysSkipsWrapper(test)
            % wrapper="None" always copies the original, even for large.
            import prodserver.mcp.MCPConstants
            [wrappers,~] = prodserver.mcp.internal.wrapForMCP(...
                "toyToolOne", MCPConstants.NoWrapper, test.tempFolder);

            [~,file] = fileparts(wrappers);
            test.verifyEqual(file, "toyToolOne");
        end

        function autoCaseInsensitive(test)
            % "auto", "AUTO", "Auto" should all work.
            import prodserver.mcp.MCPConstants
            [w1,~] = prodserver.mcp.internal.wrapForMCP(...
                "toyScalarOne", "auto", test.tempFolder);
            [~,f1] = fileparts(w1);
            test.verifyEqual(f1, "toyScalarOne");

            [w2,~] = prodserver.mcp.internal.wrapForMCP(...
                "toyScalarOne", "AUTO", test.tempFolder);
            [~,f2] = fileparts(w2);
            test.verifyEqual(f2, "toyScalarOne");
        end

        function autoSkipsForNoArgBlock(test)
            % Functions without argument blocks: Auto skips wrapper.
            import prodserver.mcp.MCPConstants
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());

            [wrappers,~] = prodserver.mcp.internal.wrapForMCP(...
                "schemaComputeNoBlock", MCPConstants.AutoWrapper, ...
                test.tempFolder);
            [~,file] = fileparts(wrappers);
            test.verifyEqual(file, "schemaComputeNoBlock");
        end

        function autoRethrowsNonArgBlockErrors(test)
            % Errors other than missing arg blocks propagate.
            import prodserver.mcp.MCPConstants
            test.verifyError(...
                @() prodserver.mcp.internal.wrapForMCP(...
                    "nonExistentFunction_xyz999", ...
                    MCPConstants.AutoWrapper, test.tempFolder), ...
                "prodserver:mcp:ToolFcnNotFound");
        end

    end
end
