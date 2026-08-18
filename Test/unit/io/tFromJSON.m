classdef tFromJSON < matlab.unittest.TestCase
% Test prodserver.mcp.io.fromJSON (deserialize a MATLAB value from JSON).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tNativeArray(test)
            % A plain JSON array with no "mwdata" marker uses the native path.
            import prodserver.mcp.io.fromJSON
            test.verifyEqual(fromJSON("[1,2,3]"), [1;2;3]);
        end

        function tNativeScalar(test)
            import prodserver.mcp.io.fromJSON
            test.verifyEqual(fromJSON("5"), 5);
        end

        function tMatrixRoundTrip(test)
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            m = hilb(3);
            test.verifyEqual(fromJSON(toJSON(m)), m, "AbsTol", 1e-12);
        end

        function tStringRoundTrip(test)
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            test.verifyEqual(fromJSON(toJSON("hello")), "hello");
        end

        function tStructRoundTrip(test)
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            s.a = 1;
            s.b = "x";
            test.verifyEqual(fromJSON(toJSON(s)), s);
        end

        function tCellRoundTrip(test)
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            c = {1, "two", [3 4]};
            test.verifyEqual(fromJSON(toJSON(c)), c);
        end

        function tEmulateMPSDecode(test)
            % The EmulateMPS wrapper must decode back to the original value even
            % when routed through the reconStruct path explicitly.
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            m = magic(4);
            json = toJSON(m, "EmulateMPS");
            test.verifyEqual(fromJSON(json, "EmulateMPS"), m);
        end

        function tExplicitNativeEncoder(test)
            import prodserver.mcp.io.fromJSON
            test.verifyEqual(fromJSON("[10,20]", "Native"), [10;20]);
        end

    end

end
