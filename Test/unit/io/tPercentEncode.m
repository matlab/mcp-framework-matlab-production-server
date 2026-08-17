classdef tPercentEncode < matlab.unittest.TestCase
% Test prodserver.mcp.io.percentEncode (percent-encode URI characters).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tSpaceEncoded(test)
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("a b"), "a%20b");
        end

        function tUnreservedUntouched(test)
            % Letters, digits and .-_~ are never encoded.
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("Abc-123._~"), "Abc-123._~");
        end

        function tDefaultExceptKeepsReserved(test)
            % By default the reserved URI characters (incl. "/" and ":") pass
            % through unencoded.
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("file:/a/b"), "file:/a/b");
        end

        function tOnlyEncodesListedChars(test)
            % only=... clears the default exceptions and encodes just the given
            % characters, so "/" and " " both get encoded.
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("a/b c", only="/"), "a%2Fb%20c");
        end

        function tExceptOverridesDefault(test)
            import prodserver.mcp.io.percentEncode
            % Space is normally encoded; add it to except to keep it.
            test.verifyEqual(percentEncode("a b", except=" "), "a b");
        end

        function tClassPreservedForChar(test)
            % Char input is converted internally but the result is a string.
            import prodserver.mcp.io.percentEncode
            out = percentEncode('a b');
            test.verifyClass(out, "string");
            test.verifyEqual(out, "a%20b");
        end

        function tStringArrayElementwise(test)
            % Each element of a string array is encoded independently.
            import prodserver.mcp.io.percentEncode
            out = percentEncode(["a b", "c/d"]);
            test.verifyEqual(out, ["a%20b", "c/d"]);
        end

    end

end
