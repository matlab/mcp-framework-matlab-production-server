classdef tSessionToken < matlab.unittest.TestCase
% Test the 2025-06-18 session token: prodserver.mcp.protocol.v20250618
% encodeSession and decodeSession.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        UI = "io.modelcontextprotocol/ui"
        AppMime = "text/html;profile=mcp-app"
        MaxLength = prodserver.mcp.protocol.v20250618.Constants.SessionTokenMaxLength
    end

    methods (Test)

        function tRoundTrip(test)
        % A client's full declaration survives the round trip.
            import prodserver.mcp.protocol.v20250618.*
            declared = jsondecode(['{"roots":{"listChanged":true},' ...
                '"extensions":{"io.modelcontextprotocol/ui":' ...
                '{"mimeTypes":["text/html;profile=mcp-app"]}}}']);
            token = encodeSession(declared);
            [sid, caps, ok] = decodeSession(token);
            test.verifyTrue(ok);
            test.verifyEqual(strlength(sid), 36, "sid should be a UUID");
            test.verifyTrue(supports(caps, test.UI));
            test.verifyEqual(string(extension(caps, test.UI).mimeTypes), test.AppMime);
            test.verifyTrue(caps.Roots.listChanged);
        end

        function tEmptyDeclaration(test)
            import prodserver.mcp.protocol.v20250618.*
            [~, caps, ok] = decodeSession(encodeSession(struct()));
            test.verifyTrue(ok);
            test.verifyFalse(supports(caps, test.UI));
            [~, ~, ok] = decodeSession(encodeSession());
            test.verifyTrue(ok, "No declaration at all is a valid session too");
        end

        function tFormat(test)
        % v1., then only URL-safe Base64: visible ASCII, safe in a header.
            import prodserver.mcp.protocol.v20250618.*
            token = encodeSession(jsondecode( ...
                '{"extensions":{"io.modelcontextprotocol/ui":{}}}'));
            test.verifyTrue(startsWith(token, "v1."));
            test.verifyTrue(matches(extractAfter(token, 3), ...
                asManyOfPattern(alphanumericsPattern | "-" | "_", 1)), token);
        end

        function tUniqueSessions(test)
        % The same declaration gives different sessions.
            import prodserver.mcp.protocol.v20250618.*
            [sid1, ~, ~] = decodeSession(encodeSession(struct()));
            [sid2, ~, ~] = decodeSession(encodeSession(struct()));
            test.verifyNotEqual(sid1, sid2);
        end

        function tReducedToNames(test)
        % A declaration too big for the budget keeps the names of what was
        % declared, without the settings.
            import prodserver.mcp.protocol.v20250618.*
            declared = jsondecode(['{"experimental":{"big":"' ...
                repmat('x', 1, 2000) '"},' ...
                '"extensions":{"io.modelcontextprotocol/ui":' ...
                '{"mimeTypes":["text/html;profile=mcp-app"]}}}']);
            token = encodeSession(declared);
            test.verifyLessThanOrEqual(strlength(token), test.MaxLength);
            [~, caps, ok] = decodeSession(token);
            test.verifyTrue(ok);
            test.verifyTrue(supports(caps, test.UI));
            test.verifyEmpty(fieldnames(extension(caps, test.UI)), ...
                "Settings should have been dropped");
            test.verifyClass(caps.Experimental, "struct");
        end

        function tReducedToFrameworkExtensions(test)
        % If even the names don't fit, only the extensions the framework
        % uses are kept.
            import prodserver.mcp.protocol.v20250618.*
            ext.(matlab.lang.makeValidName(test.UI)) = struct();
            for n = 1:60
                ext.("org_example_vendor_extension_number_" + n) = struct();
            end
            token = encodeSession(struct("extensions", ext));
            test.verifyLessThanOrEqual(strlength(token), test.MaxLength);
            [~, caps, ok] = decodeSession(token);
            test.verifyTrue(ok);
            test.verifyTrue(supports(caps, test.UI));
            test.verifyFalse(supports(caps, "org.example.vendor.extension.number.1"));
        end

        function tUnreadable(test)
        % Anything encodeSession didn't issue is unreadable, and never an
        % error.
            import prodserver.mcp.protocol.v20250618.*
            b64 = @(s) string(prodserver.mcp.internal.base64encode( ...
                unicode2native(s, "UTF-8"), URLSafe=true));
            cases = { ...
                string(matlab.lang.internal.uuid), "plain UUID"; ...
                "v2." + b64('{"sid":"a","caps":{}}'), "unknown prefix"; ...
                "v1.!!!", "not Base64"; ...
                "v1." + b64('not json'), "not JSON"; ...
                "v1." + b64('{"caps":{}}'), "no sid"; ...
                "v1." + b64('{"sid":"","caps":{}}'), "empty sid"; ...
                "v1." + b64('{"sid":"a"}'), "no caps"; ...
                "v1." + b64('[1,2]'), "not an object"; ...
                "v1." + b64('{"sid":["a","b"],"caps":{}}'), "sid an array"; ...
                "v1." + b64('{"sid":[["a"],["b"]],"caps":{}}'), "sid nested arrays"; ...
                "v1." + b64('{"sid":7,"caps":{}}'), "sid a number"; ...
                "v1." + b64('{"sid":{"x":1},"caps":{}}'), "sid an object"; ...
                "v1." + repmat('A', 1, test.MaxLength), "too long"; ...
                "", "empty"; ...
                string(missing), "missing"; ...
                5, "not text"};
            for n = 1:size(cases, 1)
                [sid, caps, ok] = decodeSession(cases{n,1});
                test.verifyFalse(ok, cases{n,2});
                test.verifyEqual(sid, "", cases{n,2});
                test.verifyFalse(supports(caps, test.UI), cases{n,2});
            end
        end

        function tTooLongThoughReadable(test)
        % A well-formed token longer than the limit is unreadable: the
        % length alone refuses it. The same payload, shorter, is read.
            import prodserver.mcp.protocol.v20250618.*
            b64 = @(s) string(prodserver.mcp.internal.base64encode( ...
                unicode2native(s, "UTF-8"), URLSafe=true));
            token = @(pad) "v1." + b64(['{"sid":"a","caps":{"experimental":' ...
                '{"pad":"' repmat('x', 1, pad) '"}}}']);
            short = token(10);
            [~, ~, ok] = decodeSession(short);
            test.assertTrue(ok, "The short form should be readable");
            long = token(test.MaxLength);
            test.assertGreaterThan(strlength(long), test.MaxLength);
            [sid, ~, ok] = decodeSession(long);
            test.verifyFalse(ok);
            test.verifyEqual(sid, "");
        end

        function tMalformedDeclaration(test)
        % A declaration that isn't an object is encoded as declaring
        % nothing.
            import prodserver.mcp.protocol.v20250618.*
            [~, caps, ok] = decodeSession(encodeSession("not a struct"));
            test.verifyTrue(ok);
            test.verifyFalse(supports(caps, test.UI));
        end

    end
end
