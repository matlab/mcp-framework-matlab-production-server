classdef tMockTest < matlab.unittest.TestCase

% Copyright 2026 The MathWorks, Inc.

    methods(Test)
        function passing(test)
            test.verifyTrue(true);
        end
    end
end
