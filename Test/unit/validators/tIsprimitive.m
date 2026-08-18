classdef tIsprimitive < matlab.unittest.TestCase
% Test prodserver.mcp.validation.isprimitive (true for MATLAB primitive,
% non-container types; false for struct/cell containers).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tNumericIsPrimitive(test)
            import prodserver.mcp.validation.isprimitive
            test.verifyTrue(isprimitive(5));
            test.verifyTrue(isprimitive(true));
        end

        function tTextIsPrimitive(test)
            import prodserver.mcp.validation.isprimitive
            test.verifyTrue(isprimitive("a"));
            test.verifyTrue(isprimitive('ab'));
        end

        function tStructIsNotPrimitive(test)
            import prodserver.mcp.validation.isprimitive
            test.verifyFalse(isprimitive(struct("a", 1)));
        end

        function tCellIsNotPrimitive(test)
            import prodserver.mcp.validation.isprimitive
            test.verifyFalse(isprimitive({1}));
        end

    end

end
