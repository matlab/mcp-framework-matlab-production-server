classdef tFailingTest < matlab.unittest.TestCase

% Copyright 2026 The MathWorks, Inc.

    methods(Test)
        function deliberateFailure(test)
            test.verifyTrue(false, "Deliberate test failure for testing.");
        end
    end
end
