classdef tMediaType < matlab.unittest.TestCase
% Test prodserver.mcp.internal.mediaType, the one normalization every
% media-type comparison goes through (decodeBody, acceptsJson,
% isMIMETypeText).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function bareTypeIsUnchanged(test)
            test.verifyEqual(mt("application/json"), "application/json");
        end

        function parametersAreRemoved(test)
            test.verifyEqual(mt("application/json; charset=utf-8"), ...
                "application/json");
            test.verifyEqual(mt("application/json;charset=utf-8"), ...
                "application/json");
            test.verifyEqual(mt("text/plain;q=0.9;format=flowed"), ...
                "text/plain");
        end

        function whitespaceBeforeSemicolonIsTrimmed(test)
            % The ordering bug: trim, THEN strip parameters, leaves the
            % space that sat before the ';'.
            test.verifyEqual(mt("text/plain ; charset=utf-8"), "text/plain");
            test.verifyEqual(mt(sprintf("text/plain\t;x=y")), "text/plain");
        end

        function surroundingWhitespaceIsTrimmed(test)
            test.verifyEqual(mt("  application/json  "), "application/json");
        end

        function caseIsFolded(test)
            test.verifyEqual(mt("Application/JSON; Charset=UTF-8"), ...
                "application/json");
        end

        function charInputGivesString(test)
            test.verifyEqual(mt('text/html; charset=utf-8'), "text/html");
        end

        function arrayIsNormalizedElementwise(test)
            test.verifyEqual(mt(["Text/Plain ;q=1", " */*", "application/*;q=0.1"]), ...
                ["text/plain", "*/*", "application/*"]);
        end

        function emptyInputIsStringEmpty(test)
            % decodeBody relies on isempty to mean "no Content-Type".
            for v = {[], '', string.empty}
                r = mt(v{1});
                test.verifyClass(r, "string");
                test.verifyEmpty(r);
            end
        end

    end
end

function r = mt(v)
    r = prodserver.mcp.internal.mediaType(v);
end
