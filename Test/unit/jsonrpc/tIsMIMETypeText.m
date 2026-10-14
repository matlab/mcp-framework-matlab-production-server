classdef tIsMIMETypeText < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.isMIMETypeText, which decides whether
% resources/read returns a resource as text or as a base64 blob.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function textTypesAreText(test)
            for t = ["text/plain", "text/html", "text/csv", "text/x-matlab"]
                test.verifyTrue(isText(t), t);
            end
        end

        function textApplicationSubtypesAreText(test)
            for t = ["application/json", "application/xml", ...
                    "application/yaml", "application/javascript", ...
                    "application/ld+json", "application/atom+xml", ...
                    "application/vnd.foo+yaml"]
                test.verifyTrue(isText(t), t);
            end
        end

        function binaryTypesAreNotText(test)
            for t = ["application/octet-stream", "image/png", "audio/mpeg", ...
                    "application/pdf", "image/svg"]
                test.verifyFalse(isText(t), t);
            end
        end

        function parametersAreIgnored(test)
            test.verifyTrue(isText("text/plain; charset=utf-8"));
            test.verifyTrue(isText("application/json;charset=UTF-8"));
            test.verifyFalse(isText("image/png; foo=bar"));
        end

        function whitespaceBeforeParametersIsIgnored(test)
            % The trim-before-strip bug: "text/plain " was left behind,
            % failed every rule, and a text resource was served as a blob.
            test.verifyTrue(isText("text/plain ; charset=utf-8"));
            test.verifyTrue(isText("application/json ;charset=utf-8"));
        end

        function caseIsIgnored(test)
            test.verifyTrue(isText("TEXT/Plain"));
            test.verifyTrue(isText('Application/JSON'));
        end

        function malformedTypesAreNotText(test)
            for t = {"", "text", "/plain", "text/", "a/b/c", '', [], string.empty}
                test.verifyFalse(isText(t{1}));
            end
        end

    end
end

function tf = isText(t)
    tf = prodserver.mcp.jsonrpc.isMIMETypeText(t);
end
