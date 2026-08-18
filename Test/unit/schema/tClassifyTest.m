classdef tClassifyTest < matlab.unittest.TestCase
%tClassifyTest Unit tests for prodserver.mcp.internal.classifyTest.

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
            tmpFile = fullfile(tempdir, "classifyTest_fh_" + ...
                matlab.lang.internal.uuid() + ".txt");
            cleanup = onCleanup(@() delete(tmpFile)); 
            prodserver.mcp.internal.classifyTest(...
                @() writelines("executed", tmpFile));
            test.verifyTrue(isfile(tmpFile));
        end

        function cellArrayMixed(test)
            tmpFile = fullfile(tempdir, "classifyTest_cell_" + ...
                matlab.lang.internal.uuid() + ".txt");
            cleanup = onCleanup(@() delete(tmpFile)); 
            prodserver.mcp.internal.classifyTest({...
                @() writelines("executed", tmpFile), ...
                "mockScript"});
            test.verifyTrue(isfile(tmpFile));
        end

        function stringTestFile(test)
            testFile = fullfile(test.mockFolder, "tMockTest.m");
            prodserver.mcp.internal.classifyTest(testFile);
            test.verifyTrue(true);
        end

        function stringNonTestFile(test)
            funcFile = fullfile(test.mockFolder, "mockFunction.m");
            prodserver.mcp.internal.classifyTest(funcFile);
            test.verifyTrue(true);
        end

        function stringFolder(test)
            prodserver.mcp.internal.classifyTest(test.mockFolder);
            test.verifyTrue(true);
        end

        function stringScriptName(test)
            prodserver.mcp.internal.classifyTest("mockScript");
            test.verifyTrue(true);
        end

        function notFoundErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest("nonExistentFunction_xyz"), ...
                "prodserver:mcp:TestSpecificationNotFound");
        end

        function invalidTypeErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(42), ...
                "prodserver:mcp:InvalidTestType");
        end

        function testDetectionByName(test)
            import prodserver.mcp.internal.classifyTest
            testFile = fullfile(test.mockFolder, "tMockTest.m");
            classifyTest(testFile);
            test.verifyTrue(true);
        end

        % --- Package-path test ---

        function packageClassPath(test)
            pkgFile = fullfile(test.mockFolder, ...
                "+mock", "+pkg", "tPackageTest.m");
            prodserver.mcp.internal.classifyTest(pkgFile);
            test.verifyTrue(true);
        end

        % --- Negative tests: non-existent paths ---

        function nonExistentFileErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(...
                    fullfile(test.mockFolder, "doesNotExist.m")), ...
                "prodserver:mcp:TestSpecificationNotFound");
        end

        function nonExistentFolderErrors(test)
            % A string that is neither a folder nor a file on disk
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(...
                    fullfile(test.mockFolder, "noSuchFolder", "noFile.m")), ...
                "prodserver:mcp:TestSpecificationNotFound");
        end

        % --- Negative tests: invalid content ---

        function nonMatlabFileErrors(test)
            % .txt file exists on path but cannot be run as MATLAB code
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(...
                    fullfile(test.mockFolder, "notMatlab.txt")), ...
                "prodserver:mcp:TestFileFailed");
        end

        function invalidSyntaxErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(...
                    fullfile(test.mockFolder, "invalidSyntax.m")), ...
                "prodserver:mcp:TestFileFailed");
        end

        function runtimeErrorInScript(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(...
                    fullfile(test.mockFolder, "runtimeError.m")), ...
                "prodserver:mcp:TestFileFailed");
        end

        % --- Negative tests: failing test suites ---

        function failingTestFileErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(...
                    fullfile(test.suiteFolder, "tFailingTest.m")), ...
                "prodserver:mcp:TestFileFailed");
        end

        function failingFolderErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(test.suiteFolder), ...
                "prodserver:mcp:TestSuiteFailed");
        end

    end
end
