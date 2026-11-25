classdef tUri2jsonCall < matlab.unittest.TestCase
% uri2json through tools/call, as an MCP App's view calls it: on a server
% built with an app, from a client that declared MCP Apps support, with a
% file: URI. The data comes back as a tool output's numbers do: always an
% array, NaN as null, and Inf and -Inf as text.

% Copyright 2026 The MathWorks, Inc.

    properties
        folder
    end

    methods (TestClassSetup)
        function initPath(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(fullfile( ...
                prodserver.mcp.internal.packageFolder(), "server", "tools")));
        end
    end

    methods (TestMethodSetup)
        function buildApp(test)
        % The definitions build writes for toyToolOne with an app, which
        % include uri2json's.
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.folder = tFolder.Folder;
            app = fullfile(test.folder, "view.html");
            writelines("<html><body>view</body></html>", app);
            prodserver.mcp.build("toyToolOne", folder=test.folder, ...
                stop="Definition", app=app);
            test.applyFixture(PathFixture(test.folder));

            % The definitions are cached; clear them now and afterwards.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function tNumbersArrive(test)
            test.verifyEqual(test.dataOf([1; 2; 3]), '[1,2,3]');
        end

        function tNonFiniteNumbersArrive(test)
        % Without a schema for data, plain JSON would refuse Inf.
            test.verifyEqual(test.dataOf([1; Inf; NaN; -Inf]), ...
                '[1,"Inf",null,"-Inf"]');
        end

        function tOneValueIsAnArray(test)
            test.verifyEqual(test.dataOf(5), '[5]');
            test.verifyEqual(test.dataOf(Inf), '["Inf"]');
        end

        function tMatrixRows(test)
            test.verifyEqual(test.dataOf([1 2; 3 Inf]), '[[1,2],[3,"Inf"]]');
        end

        function tResultMatchesItsOwnText(test)
        % The text content is the structured content, encoded.
            r = test.callWith([1; Inf]);
            test.verifyEqual(string(r.content{1}.text), ...
                string(jsonencode(r.structuredContent)));
        end

    end

    methods (Access = private)

        function text = dataOf(test, values)
        % The JSON text of result.data, for a file holding VALUES, as the
        % view receives it: the text content is the structured content,
        % encoded, {"result":{"data":...}}.
            r = test.callWith(values);
            whole = string(r.content{1}.text);
            test.assertTrue(startsWith(whole, '{"result":{"data":') && ...
                endsWith(whole, "}}"), whole);
            text = char(extractBetween(whole, strlength('{"result":{"data":') + 1, ...
                strlength(whole) - 2));
        end

        function r = callWith(test, values)
        % Call uri2json as an app host would, on a CSV file holding VALUES.
            import prodserver.mcp.protocol.ClientCapabilities
            csv = fullfile(test.folder, "data.csv");
            writematrix(values, csv);
            caps = ClientCapabilities(struct("extensions", struct( ...
                matlab.lang.makeValidName(prodserver.mcp.MCPConstants.UIExtension_JSON), ...
                struct())));
            ctx = prodserver.mcp.protocol.RequestContext("2025-06-18", ...
                Capabilities=caps);
            jrpc = struct("jsonrpc", "2.0", "id", 2, "method", "tools/call", ...
                "params", struct("name", "uri2json", "arguments", struct( ...
                    "uri", prodserver.mcp.io.uri.File.Path2FileURI(csv))));
            evalc("result = prodserver.mcp.handler.tools.call(jrpc, ctx);");
            test.assertFalse(isfield(result.result, "isError"), ...
                "uri2json failed: " + jsonencode(result.result));
            r = result.result;
        end

    end
end
