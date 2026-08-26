classdef tClassifyExample < matlab.unittest.TestCase
%tClassifyExample Unit tests for prodserver.mcp.internal.classifyExample.

% Copyright 2026 The MathWorks, Inc.

    properties
        mockFolder
        suiteFolder
    end

    methods(TestClassSetup)
        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture

            pkgFolder = prodserver.mcp.internal.packageFolder();
            test.applyFixture(PathFixture(pkgFolder));

            test.mockFolder = fullfile(pkgFolder,"Test", "mocks", "classify");
            test.suiteFolder = fullfile(fileparts(test.mockFolder),"failingSuite");
            test.applyFixture(PathFixture(test.mockFolder));
        end
    end

    methods(Test)

        function functionHandleExecutes(test)
            tmpFile = fullfile(tempdir, "classifyExample_fh_" + ...
                matlab.lang.internal.uuid() + ".txt");
            cleanup = onCleanup(@() delete(tmpFile));
            prodserver.mcp.internal.classifyExample(...
                @() writelines("executed", tmpFile));
            test.verifyTrue(isfile(tmpFile));
        end

        function cellArrayMixed(test)
            tmpFile = fullfile(tempdir, "classifyExample_cell_" + ...
                matlab.lang.internal.uuid() + ".txt");
            cleanup = onCleanup(@() delete(tmpFile));
            prodserver.mcp.internal.classifyExample({...
                @() writelines("executed", tmpFile), ...
                "mockScript"});
            test.verifyTrue(isfile(tmpFile));
        end

        function stringTestFile(test)
            testFile = fullfile(test.mockFolder, "tMockTest.m");
            prodserver.mcp.internal.classifyExample(testFile);
            test.verifyTrue(true);
        end

        function stringNonTestFile(test)
            funcFile = fullfile(test.mockFolder, "mockFunction.m");
            prodserver.mcp.internal.classifyExample(funcFile);
            test.verifyTrue(true);
        end

        function stringFolder(test)
            prodserver.mcp.internal.classifyExample(test.mockFolder);
            test.verifyTrue(true);
        end

        function stringScriptName(test)
            prodserver.mcp.internal.classifyExample("mockScript");
            test.verifyTrue(true);
        end

        function notFoundErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample("nonExistentFunction_xyz"), ...
                "prodserver:mcp:ExampleSpecificationNotFound");
        end

        function invalidTypeErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(42), ...
                "prodserver:mcp:InvalidExampleType");
        end

        function testDetectionByName(test)
            import prodserver.mcp.internal.classifyExample
            testFile = fullfile(test.mockFolder, "tMockTest.m");
            classifyExample(testFile);
            test.verifyTrue(true);
        end

        % --- Package-path test ---

        function packageClassPath(test)
            pkgFile = fullfile(test.mockFolder, ...
                "+mock", "+pkg", "tPackageTest.m");
            prodserver.mcp.internal.classifyExample(pkgFile);
            test.verifyTrue(true);
        end

        % --- Negative tests: non-existent paths ---

        function nonExistentFileErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(...
                    fullfile(test.mockFolder, "doesNotExist.m")), ...
                "prodserver:mcp:ExampleSpecificationNotFound");
        end

        function nonExistentFolderErrors(test)
            % A string that is neither a folder nor a file on disk
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(...
                    fullfile(test.mockFolder, "noSuchFolder", "noFile.m")), ...
                "prodserver:mcp:ExampleSpecificationNotFound");
        end

        % --- Negative tests: invalid content ---

        function nonMatlabFileErrors(test)
            % .txt file exists on path but cannot be run as MATLAB code
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(...
                    fullfile(test.mockFolder, "notMatlab.txt")), ...
                "prodserver:mcp:ExampleFileFailed");
        end

        function invalidSyntaxErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(...
                    fullfile(test.mockFolder, "invalidSyntax.m")), ...
                "prodserver:mcp:ExampleFileFailed");
        end

        function runtimeErrorInScript(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(...
                    fullfile(test.mockFolder, "runtimeError.m")), ...
                "prodserver:mcp:ExampleFileFailed");
        end

        % --- Negative tests: failing test suites ---

        function failingTestFileErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(...
                    fullfile(test.suiteFolder, "tFailingTest.m")), ...
                "prodserver:mcp:ExampleFileFailed");
        end

        function failingFolderErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyExample(test.suiteFolder), ...
                "prodserver:mcp:ExampleSuiteFailed");
        end

    end
end
