classdef tBuildTests < matlab.unittest.TestCase
%tBuildTests Unit tests for the example parameter in prodserver.mcp.build.

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
    end

    methods(TestMethodSetup)
        function setup(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tfolder = TemporaryFolderFixture(WithSuffix="buildTests");
            test.applyFixture(tfolder);
            test.tempFolder = tfolder.Folder;

            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function testsGeneratesDefinition(test)
            import prodserver.mcp.MCPConstants

            fcn = "schemaComputeNoBlock";
            prodserver.mcp.build(fcn, ...
                example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                folder=test.tempFolder, ...
                archive="buildTestsDef", stop="Definition");

            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            test.verifyEqual(exist(defFile, "file"), 2, ...
                "Definition file should exist");

            def = load(defFile);
            def = def.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t)string(t.name), def.tools);
            test.verifyTrue(ismember(fcn, names), ...
                fcn + " not in definition");
        end

        function testsAndDefinitionErrors(test)
            fcn = "schemaComputeNoBlock";
            defs = prodserver.mcp.schema(fcn, ...
                @() schemaComputeNoBlock(1.0, 2.0, 3.0));

            test.verifyError(...
                @() prodserver.mcp.build(fcn, ...
                    example=@() schemaComputeNoBlock(1.0, 2.0, 3.0), ...
                    definition=defs, ...
                    folder=test.tempFolder, archive="conflict"), ...
                "prodserver:mcp:ExampleDefinitionConflict");
        end

        function testsEmptyNoEffect(test)
            import prodserver.mcp.MCPConstants

            fcn = "schemaCompute";
            prodserver.mcp.build(fcn, example=[], ...
                folder=test.tempFolder, ...
                archive="buildTestsEmpty", stop="Definition");

            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            test.verifyEqual(exist(defFile, "file"), 2, ...
                "Definition file should exist via mcpDefinition path");
        end

        function testsMultiToolBuild(test)
            import prodserver.mcp.MCPConstants

            fcns = ["schemaComputeNoBlock", "schemaVectorNoBlock"];
            prodserver.mcp.build(fcns, ...
                example=@() exerciseMultiTool(), ...
                folder=test.tempFolder, ...
                archive="buildTestsMulti", stop="Definition");

            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            def = load(defFile);
            def = def.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t)string(t.name), def.tools);
            for n = 1:numel(fcns)
                test.verifyTrue(ismember(fcns(n), names), ...
                    fcns(n) + " not in definition");
            end
        end

    end
end

function exerciseMultiTool()
    [~,~,~] = schemaComputeNoBlock(1.0, 2.0, 3.0);
    [~,~,~] = schemaVectorNoBlock([1.0, 2.0, 3.0], 2.0);
end
