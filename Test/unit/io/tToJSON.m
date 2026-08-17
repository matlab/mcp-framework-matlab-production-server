classdef tToJSON < matlab.unittest.TestCase
% Test prodserver.mcp.io.toJSON (serialize a MATLAB value to JSON).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tScalarRoundTrip(test)
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            test.verifyEqual(fromJSON(toJSON(5)), 5);
        end

        function tMatrixRoundTrip(test)
            import prodserver.mcp.io.toJSON
            import prodserver.mcp.io.fromJSON
            m = magic(3);
            test.verifyEqual(fromJSON(toJSON(m)), m);
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
            actual = fromJSON(toJSON(c));
            test.verifyEqual(actual, c);
        end

        function tNativeIsValidJSON(test)
            % "Native" format must be decodable by jsondecode.
            import prodserver.mcp.io.toJSON
            json = toJSON([1 2 3], "Native");
            test.verifyEqual(jsondecode(json), [1;2;3]);
        end

        function tOutputIsText(test)
            import prodserver.mcp.io.toJSON
            json = toJSON(42);
            test.verifyTrue(ischar(json) || isstring(json));
        end

        function tEmulateMPSHasWrapper(test)
            % The EmulateMPS path always emits the mwdata/mwtype/mwsize wrapper,
            % independent of whether the MPS built-in encoder is present.
            import prodserver.mcp.io.toJSON
            json = string(toJSON(5, "EmulateMPS"));
            test.verifyTrue(contains(json, "mwdata"));
            test.verifyTrue(contains(json, "mwtype"));
            test.verifyTrue(contains(json, "mwsize"));
        end

    end

end
