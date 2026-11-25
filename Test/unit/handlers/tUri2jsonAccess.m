classdef tUri2jsonAccess < matlab.unittest.TestCase
% uri2json is offered only to clients that declared MCP Apps support:
% tools/list leaves it out for other clients, and tools/call refuses it to
% them, as an unknown tool, counting the refusal. An archive built without
% an app has no uri2json, so a call to it counts nothing.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        UI = prodserver.mcp.MCPConstants.UIExtension_JSON
    end

    properties
        definitionFile
    end

    methods (TestMethodSetup)
        function seedDefinitions(test)
        % Definitions for a user tool and uri2json, as build makes them for
        % an app. The handlers only look at the names.
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.applyFixture(PathFixture(tFolder.Folder));
            def.(MCPConstants.DefinitionVariable).tools = { ...
                struct("name", "toyToolOne"), ...
                struct("name", MCPConstants.Uri2JsonTool)};
            def.(MCPConstants.ResourceVariable) = {};
            def.(MCPConstants.AppResourceVariable) = true;
            test.definitionFile = fullfile(tFolder.Folder, MCPConstants.DefinitionFile);
            save(test.definitionFile, "-struct", "def");

            % The definitions are cached; clear them now and afterwards.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function tListedForAppHosts(test)
            names = test.listedNames(test.context(true));
            test.verifyEqual(names, ["toyToolOne", "uri2json"]);
        end

        function tHiddenFromOtherClients(test)
            names = test.listedNames(test.context(false));
            test.verifyEqual(names, "toyToolOne");
        end

        function tRefusedToOtherClients(test)
        % Refused with the unknown-tool error, and counted as refused, in
        % total and for the serving revision.
            [me, counters] = test.call(test.context(false));
            test.verifyEqual(me.identifier, 'prodserver:mcp:ToolUnavailable');
            test.verifyTrue(ismember("MCP_uri2json_Refused", counters));
            test.verifyTrue(ismember("MCP_uri2json_Refused_2025_06_18", counters));
        end

        function tUnknownWithoutApp(test)
        % An archive built without an app has no uri2json: calling it is
        % calling an unknown tool, which isn't a refusal and counts nothing.
            import prodserver.mcp.MCPConstants
            def.(MCPConstants.DefinitionVariable).tools = { ...
                struct("name", "toyToolOne")};
            def.(MCPConstants.ResourceVariable) = {};
            save(test.definitionFile, "-struct", "def");
            prodserver.mcp.handler.toolServices(action="clear");

            [me, counters] = test.call(test.context(false));
            test.verifyEqual(me.identifier, 'prodserver:mcp:ToolUnavailable');
            test.verifyEmpty(counters, strjoin(counters, ", "));
        end

        function tNotRefusedToAppHosts(test)
        % An app host gets past the check. The seeded definition is only a
        % name, so the call fails later; but it isn't a refusal, counted or
        % not. tUri2jsonCall calls it with a full definition.
            [me, counters] = test.call(test.context(true));
            test.verifyFalse(any(contains(counters, "_Refused")), ...
                strjoin(counters, ", "));
            if ~isempty(me)
                test.verifyNotEqual(me.identifier, 'prodserver:mcp:ToolUnavailable', ...
                    me.message);
            end
        end

    end

    methods (Access = private)

        function ctx = context(test, apps)
        % A 2025-06-18 request's context, with or without MCP Apps support.
            import prodserver.mcp.protocol.ClientCapabilities
            if apps
                caps = ClientCapabilities(struct("extensions", ...
                    struct(matlab.lang.makeValidName(test.UI), struct())));
            else
                caps = ClientCapabilities.none();
            end
            ctx = prodserver.mcp.protocol.RequestContext("2025-06-18", ...
                Capabilities=caps);
        end

        function names = listedNames(~, ctx)
            jrpc = struct("jsonrpc", "2.0", "id", 1, "method", "tools/list");
            result = prodserver.mcp.handler.tools.list(jrpc, ctx);
            names = cellfun(@(t) string(t.name), result.result.tools);
        end

        function [me, counters] = call(~, ctx)
        % Call uri2json, returning the error and the counters it emitted.
        % Outside Production Server, incrementCounter prints each counter.
            jrpc = struct("jsonrpc", "2.0", "id", 2, "method", "tools/call", ...
                "params", struct("name", "uri2json", ...
                    "arguments", struct("uri", "ui://app/app.html")));
            me = [];
            output = evalc("try, prodserver.mcp.handler.tools.call(jrpc, ctx); catch me, end");
            lines = splitlines(string(output));
            lines = lines(startsWith(lines, "[metric:counter]"));
            % [metric:counter] <version>|<name> <value>
            counters = string.empty;
            for n = 1:numel(lines)
                parts = split(erase(lines(n), "[metric:counter] "));
                counters(end+1) = extractAfter(parts(1), "|"); %#ok<AGROW>
            end
        end

    end
end
