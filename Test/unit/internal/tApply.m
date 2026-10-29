classdef tApply < matlab.unittest.TestCase
% Test prodserver.mcp.internal.apply (map a function over a list).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function arrayList(test)
            % A non-cell list goes through arrayfun.
            import prodserver.mcp.internal.apply
            test.verifyEqual(apply(@(x)2*x,[1 2 3]),{2 4 6});
            test.verifyEqual(apply(@(x)2*x,[1 2 3],Uniform=true),[2 4 6]);
        end

        function cellList(test)
            % A cell list goes through cellfun.
            import prodserver.mcp.internal.apply
            test.verifyEqual(apply(@(x)2*x,{1 2 3}),{2 4 6});
            test.verifyEqual(apply(@(x)2*x,{1 2 3},Uniform=true),[2 4 6]);
        end

        function flatten(test)
            % Flatten concatenates the cell results.
            import prodserver.mcp.internal.apply
            test.verifyEqual(apply(@(x)[x x],[1 2],Flatten=true),[1 1 2 2]);
            test.verifyEqual(apply(@(x)[x x],{1 2},Flatten=true),[1 1 2 2]);
        end

    end

end
