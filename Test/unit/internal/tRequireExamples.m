classdef tRequireExamples < matlab.unittest.TestCase
% Test the prodserver.mcp.test.mixin.RequireExamples fixture when shared.
% The framework compares shared fixtures (isCompatible) only when two test
% classes in one run share one, so run two that do.

% Copyright 2026 The MathWorks, Inc.

    properties
        suiteFolder
    end

    methods(TestClassSetup)
        function registerPackage(test)
            import matlab.unittest.fixtures.PathFixture

            pkgFolder = prodserver.mcp.internal.packageFolder();
            test.applyFixture(PathFixture(pkgFolder));

            test.suiteFolder = fullfile(pkgFolder,"Test","mocks", ...
                "sharedExamples");
            test.applyFixture(PathFixture(test.suiteFolder));
        end
    end

    methods(Test)

        function sharedByTwoClasses(test)
            import matlab.unittest.TestSuite
            import matlab.unittest.TestRunner

            suite = [TestSuite.fromClass(?tSharedExamplesA), ...
                     TestSuite.fromClass(?tSharedExamplesB)];
            results = run(TestRunner.withNoPlugins(),suite);

            test.verifyNumElements(results,2);
            test.verifyTrue(all([results.Passed]), ...
                "Both classes sharing RequireExamples should pass.");
        end

    end

end
