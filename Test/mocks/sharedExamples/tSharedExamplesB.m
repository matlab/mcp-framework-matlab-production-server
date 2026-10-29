classdef (SharedTestFixtures={prodserver.mcp.test.mixin.RequireExamples()}) ...
        tSharedExamplesB < matlab.unittest.TestCase
% Shares RequireExamples with tSharedExamplesA. Run by tRequireExamples,
% not by the main suite. Tests for a bug in RequireExamples implementation
% of isCompatible.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)
        function examplesOnPath(test)
            test.verifyEqual(exist("primeSequence","file"),2);
        end
    end

end
