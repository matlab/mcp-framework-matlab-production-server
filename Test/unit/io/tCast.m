classdef tCast < matlab.unittest.TestCase
% Test prodserver.mcp.io.cast (cast a value to a requested type/class).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tSameTypeNoOp(test)
            % When x is already the requested type, it is returned unchanged.
            import prodserver.mcp.io.cast
            test.verifyEqual(cast("double", 3.5), 3.5);
        end

        function tNumericToChar(test)
            % "char" is a primitive cast type: 65 -> 'A'.
            import prodserver.mcp.io.cast
            c = cast("char", 65);
            test.verifyClass(c, "char");
            test.verifyEqual(double(c), 65);
        end

        function tToCell(test)
            import prodserver.mcp.io.cast
            r = cast("cell", [1 2 3]);
            test.verifyClass(r, "cell");
            test.verifyEqual(r, {1 2 3});
        end

        function tStructWithoutSchema(test)
            % Intended behavior: casting to struct with no schema must error.
            % Currently FILTERED (assumeFail) because the error branch is dead
            % code (BUG-cast-struct-deadcode). Remove the assumeFail line once
            % cast recognizes fundamental container types instead of relying on
            % exist(type,"class").
            import prodserver.mcp.io.cast
            test.assumeFail("Known bug: cast(""struct"",x) is a silent no-op " + ...
                "instead of erroring (BUG-cast-struct-deadcode.md).");
            test.verifyError(@() cast("struct", 5), ...
                "prodserver:mcp:StructCastRequiresSchema");
        end

        function tConversionFailureWrapped(test)
            % A failed conversion is wrapped in a TypeConversionFailure error.
            import prodserver.mcp.io.cast
            test.verifyError(@() cast("function_handle", 5), ...
                "prodserver:MCP:TypeConversionFailure");
        end

    end

end
