classdef tPercentDecode < matlab.unittest.TestCase
% Test prodserver.mcp.io.percentDecode (decode %XX sequences in URIs).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tSpaceDecoded(test)
            import prodserver.mcp.io.percentDecode
            test.verifyEqual(percentDecode("a%20b"), "a b");
        end

        function tLowercaseHex(test)
            import prodserver.mcp.io.percentDecode
            test.verifyEqual(percentDecode("%c3%a9"), "é");
        end

        function tMultiByteUTF8(test)
            import prodserver.mcp.io.percentDecode
            test.verifyEqual(percentDecode("%C3%A9t%C3%A9"), "été");
            test.verifyEqual(percentDecode("%E6%97%A5%E6%9C%AC"), "日本");
            test.verifyEqual(percentDecode("%F0%9F%98%80"), "😀");
        end

        function tDecodesOnce(test)
            % %25 is a literal %. Its decoding must not combine with the
            % characters after it into a new sequence, wherever another
            % sequence appears in the string.
            import prodserver.mcp.io.percentDecode
            test.verifyEqual(percentDecode("%2541"), "%41");
            test.verifyEqual(percentDecode("%2541 and %41"), "%41 and A");
        end

        function tMalformedLeftAlone(test)
            import prodserver.mcp.io.percentDecode
            test.verifyEqual(percentDecode("50%"), "50%");
            test.verifyEqual(percentDecode("%G1"), "%G1");
            test.verifyEqual(percentDecode("%4"), "%4");
            test.verifyEqual(percentDecode("%%41"), "%A");
        end

        function tCharInCharOut(test)
            import prodserver.mcp.io.percentDecode
            out = percentDecode('a%20b');
            test.verifyClass(out, "char");
            test.verifyEqual(out, 'a b');
        end

        function tStringArrayAndMissing(test)
            import prodserver.mcp.io.percentDecode
            out = percentDecode(["a%20b"; missing; ""]);
            test.verifyEqual(out(1), "a b");
            test.verifyTrue(ismissing(out(2)));
            test.verifyEqual(out(3), "");
        end

        function tParsedURIFields(test)
            import prodserver.mcp.io.percentDecode
            u.host = "h%41";
            u.userInfo = "";
            u.path = "/my%20data/x.json";
            u.query = [];
            u = percentDecode(u);
            test.verifyEqual(u.host, "hA");
            test.verifyEqual(u.path, "/my data/x.json");
            test.verifyEmpty(u.query);
        end

        function tInvertsPercentEncode(test)
            import prodserver.mcp.io.percentEncode
            import prodserver.mcp.io.percentDecode
            s = ["my data", "50% off", "a#b?c", "%41", "été", "日本", "😀", ...
                "a/b:c"];
            test.verifyEqual(percentDecode(percentEncode(s, except="/:")), s);
        end

    end

end
