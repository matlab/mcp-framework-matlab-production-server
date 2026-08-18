classdef tIsnothing < matlab.unittest.TestCase
% Test prodserver.mcp.internal.isnothing (is the input some permutation of
% "nothing" — empty, missing, all-NaN, all-zero-length strings, all-undefined).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tEmptyIsNothing(test)
            import prodserver.mcp.internal.isnothing
            test.verifyTrue(isnothing([]));
            test.verifyTrue(isnothing(""));
        end

        function tMissingIsNothing(test)
            import prodserver.mcp.internal.isnothing
            test.verifyTrue(isnothing(missing));
        end

        function tAllNaNIsNothing(test)
            % Numeric NaN counts as nothing; a mixed vector does not.
            import prodserver.mcp.internal.isnothing
            test.verifyTrue(isnothing(NaN));
            test.verifyFalse(isnothing([NaN 1]));
        end

        function tZeroLengthStringsAreNothing(test)
            import prodserver.mcp.internal.isnothing
            test.verifyTrue(isnothing(["" ""]));
        end

        function tUndefinedCategoricalIsNothing(test)
            import prodserver.mcp.internal.isnothing
            test.verifyTrue(isnothing(categorical(missing)));
        end

        function tRealValueIsNotNothing(test)
            import prodserver.mcp.internal.isnothing
            test.verifyFalse(isnothing(5));
            test.verifyFalse(isnothing("a"));
        end

    end

end
