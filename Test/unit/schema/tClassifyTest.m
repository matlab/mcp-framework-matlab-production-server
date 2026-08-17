classdef tClassifyTest < matlab.unittest.TestCase
%tClassifyTest Unit tests for prodserver.mcp.internal.classifyTest.

% Copyright 2026 The MathWorks, Inc.

    properties
        mockFolder
    end

    methods(TestClassSetup)
        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));

            test.mockFolder = fullfile(testFolder, "mocks", "classify");
            test.applyFixture(PathFixture(test.mockFolder));
        end
    end

    methods(Test)

        function functionHandleExecutes(test)
            % Verify function handle actually runs by checking side effects
            tmpFile = fullfile(tempdir, "classifyTest_fh_" + ...
                char(java.util.UUID.randomUUID()) + ".txt");
            cleanup = onCleanup(@() delete(tmpFile));
            prodserver.mcp.internal.classifyTest(...
                @() writelines("executed", tmpFile));
            test.verifyTrue(isfile(tmpFile));
        end

        function cellArrayMixed(test)
            % Cell array with function handle and string — both should execute
            tmpFile = fullfile(tempdir, "classifyTest_cell_" + ...
                char(java.util.UUID.randomUUID()) + ".txt");
            cleanup = onCleanup(@() delete(tmpFile));
            prodserver.mcp.internal.classifyTest({...
                @() writelines("executed", tmpFile), ...
                "mockScript"});
            test.verifyTrue(isfile(tmpFile));
        end

        function stringTestFile(test)
            % File starting with t + uppercase → detected as test
            testFile = fullfile(test.mockFolder, "tMockTest.m");
            % Should not error (runtests runs the passing test)
            prodserver.mcp.internal.classifyTest(testFile);
            test.verifyTrue(true);
        end

        function stringNonTestFile(test)
            % mockFunction.m does not match test naming → run as script/function
            funcFile = fullfile(test.mockFolder, "mockFunction.m");
            prodserver.mcp.internal.classifyTest(funcFile);
            test.verifyTrue(true);
        end

        function stringFolder(test)
            % Folder containing tests → calls runtests on folder
            prodserver.mcp.internal.classifyTest(test.mockFolder);
            test.verifyTrue(true);
        end

        function stringScriptName(test)
            % Script name without path → should run successfully
            prodserver.mcp.internal.classifyTest("mockScript");
            test.verifyTrue(true);
        end

        function notFoundErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest("nonExistentFunction_xyz"), ...
                "prodserver:mcp:TestNotFound");
        end

        function invalidTypeErrors(test)
            test.verifyError(...
                @() prodserver.mcp.internal.classifyTest(42), ...
                "prodserver:mcp:InvalidTestType");
        end

        function testDetectionByName(test)
            % tMockTest starts with 't' + uppercase 'M' → detected as test
            import prodserver.mcp.internal.classifyTest
            testFile = fullfile(test.mockFolder, "tMockTest.m");
            % Should call runtests (not run) — verify by checking it doesn't
            % error, since tMockTest is a valid test class.
            classifyTest(testFile);
            test.verifyTrue(true);
        end

    end
end
