classdef tHeaderSentinel < matlab.unittest.TestCase
% Test the 2026-07-28 Base64 header sentinel: encodeHeaderValue and
% decodeHeaderValue.
%
% This file exists to break a symmetry. The client encodes and the server
% decodes, so a round-trip test passes whenever the two share a defect --
% including the defect of neither implementing the sentinel at all, which is
% precisely the state Phase 3 found the code in. A green round trip would
% then certify the violation rather than catch it.
%
% So the tests below pin the ENCODED FORM against literal expected bytes
% worked out from the spec, not against whatever the decoder happens to
% accept. If encodeHeaderValue changes its output, these fail even though
% the round trip still works.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        C
    end

    methods (TestMethodSetup)
        function loadConstants(test)
            test.C = prodserver.mcp.protocol.v20260728.Constants;
        end
    end

    methods (Test)

        % --- values that must travel untouched ------------------------------

        function tPlainAsciiIsNotEncoded(test)
        % Encoding when it is not needed is a conformance problem of its own:
        % a server that does not decode sees a wrapped value it cannot match.
            for v = ["myTool", "res://data/item", "tools/call", ...
                     "a-b_c.d~e", "A1234567890"]
                test.verifyEqual( ...
                    prodserver.mcp.protocol.v20260728.encodeHeaderValue(v), ...
                    v, "must travel as-is: " + v);
            end
        end

        function tEmptyStringIsNotEncoded(test)
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.encodeHeaderValue(""), "");
        end

        % --- the expected encoded form, pinned literally --------------------

        function tNonAsciiEncodesToExpectedBytes(test)
        % "h" + U+00E9 + "llo" is UTF-8 68 C3 A9 6C 6C 6F, which Base64s to
        % aMOpbGxv. Written out so this asserts the spec's answer and not
        % the implementation's.
            value = "h" + string(char(233)) + "llo";
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.encodeHeaderValue(value), ...
                "=?base64?aMOpbGxv?=");
        end

        function tMarkersAreLowercaseAndExact(test)
        % The spec makes the markers case-sensitive, so the delimiter is
        % asserted as a literal here as well as read from Constants.
            test.verifyEqual(test.C.HeaderSentinelPrefix, "=?base64?");
            test.verifyEqual(test.C.HeaderSentinelSuffix, "?=");
        end

        function tUtf8NotUtf16(test)
        % U+00E9 alone: UTF-8 is C3 A9 -> "w6k=", UTF-16LE would be E9 00 ->
        % "6QA=" and Latin-1 would be E9 -> "6Q==". Only the first is right,
        % and the difference is invisible to a round trip that uses the same
        % wrong encoding both ways.
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.encodeHeaderValue( ...
                    string(char(233))), ...
                "=?base64?w6k=?=");
        end

        % --- each trigger, separately ---------------------------------------

        function tControlCharacterIsEncoded(test)
        % CR and LF would split the header field, or the message. This is
        % the trigger with a security edge, not just an interop one.
            value = "a" + string(newline) + "b";
            encoded = prodserver.mcp.protocol.v20260728.encodeHeaderValue(value);
            test.verifyEqual(encoded, "=?base64?YQpi?=");
            test.verifyFalse(contains(encoded, newline), ...
                "an encoded value must contain no line break");
        end

        function tLeadingOrTrailingWhitespaceIsEncoded(test)
        % A conforming HTTP intermediary may strip surrounding whitespace,
        % which silently changes the value. Encoding is what preserves it.
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.encodeHeaderValue(" x"), ...
                "=?base64?IHg=?=");
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.encodeHeaderValue("x "), ...
                "=?base64?eCA=?=");
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.encodeHeaderValue("a b"), ...
                "a b", "interior whitespace is safe and must not encode");
        end

        function tLiteralSentinelIsEncoded(test)
        % Without this rule a resource named "=?base64?Zm9v?=" and a resource
        % named "foo" send the same header, and the server cannot tell which
        % was meant.
            value = "=?base64?Zm9v?=";
            encoded = prodserver.mcp.protocol.v20260728.encodeHeaderValue(value);
            test.verifyNotEqual(encoded, value);
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.decodeHeaderValue(encoded), ...
                value, "one decode must recover the literal, not 'foo'");
        end

        % --- decode, including inputs no client of ours produces ------------

        function tDecodeIgnoresUnmarkedValues(test)
        % decodeHeaderValue runs on every header value, because the server
        % cannot know which the client chose to encode. Unmarked input must
        % come back untouched.
            for v = ["myTool", "res://data", "base64", "=?base32?aaa?=", ...
                     "?=", "=?base64?"]
                test.verifyEqual( ...
                    prodserver.mcp.protocol.v20260728.decodeHeaderValue(v), ...
                    v, "must pass through: " + v);
            end
        end

        function tDecodeIsCaseSensitive(test)
        % Uppercase markers are not the sentinel, so the value is a literal.
            v = "=?BASE64?Zm9v?=";
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.decodeHeaderValue(v), v);
        end

        function tDecodeOfGarbagePayloadDoesNotThrow(test)
        % A malformed payload is a client error whose only sanctioned answer
        % is -32020/400. Raising here instead would surface as -32603/500,
        % reporting a bad header as a server fault -- the G3 failure mode.
            for v = ["=?base64?!!!!?=", "=?base64??=", "=?base64?Zm9?="]
                try
                    out = prodserver.mcp.protocol.v20260728. ...
                        decodeHeaderValue(v);
                    test.verifyClass(out, 'string');
                catch me
                    test.verifyFail("decode must not throw on " + v + ...
                        " (got " + me.identifier + ")");
                end
            end
        end

        function tRoundTripAcrossAwkwardValues(test)
        % Weaker than the assertions above, and kept for that reason: it
        % covers values whose exact Base64 is not worth writing out, on top
        % of a format already pinned literally.
            values = [
                "myTool"
                "res://data/item"
                "h" + string(char(233)) + "llo"
                string(char(0x4E2D)) + string(char(0x6587))
                " padded "
                "=?base64?Zm9v?="
                "tab" + string(char(9)) + "separated"
                ];
            for v = values'
                encoded = prodserver.mcp.protocol.v20260728. ...
                    encodeHeaderValue(v);
                decoded = prodserver.mcp.protocol.v20260728. ...
                    decodeHeaderValue(encoded);
                test.verifyEqual(decoded, v, "round trip failed for: " + v);
            end
        end

    end

end
