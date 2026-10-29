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

        function tNonASCIIIsUTF8Bytes(test)
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("é"), "%C3%A9");
            test.verifyEqual(percentEncode("日本"), "%E6%97%A5%E6%9C%AC");
        end

        function tOutsideBMPIsOneCharacter(test)
            % A UTF-16 surrogate pair is one character: four UTF-8 bytes,
            % not two invalid halves.
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("😀"), "%F0%9F%98%80");
        end

        function tPercentEncodedUnlessExcepted(test)
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("50%"), "50%", ...
                "% is a default exception.");
            test.verifyEqual(percentEncode("50%", except="/"), "50%25");
        end

        function tExtraEncodesUnreserved(test)
            import prodserver.mcp.io.percentEncode
            test.verifyEqual(percentEncode("a.b", extra="."), "a%2Eb");
        end

        function tEmptyAndMissingUnchanged(test)
            import prodserver.mcp.io.percentEncode
            out = percentEncode(["", missing]);
            test.verifyEqual(out(1), "");
            test.verifyTrue(ismissing(out(2)));
        end

    end

end
