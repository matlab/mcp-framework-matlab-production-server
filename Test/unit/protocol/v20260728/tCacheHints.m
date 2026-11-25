classdef tCacheHints < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.cacheHints: which results carry
% ttlMs and cacheScope (conformance Phase 5, G2).

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        definitionMethod = {"server/discover", "tools/list", ...
            "resources/list", "resources/templates/list"}
        uncachedMethod = {"tools/call", "prompts/get", "completion/complete", ...
            "notifications/cancelled"}
    end

    methods (Access = private)
        function r = hinted(~, method, resultType)
            arguments
                ~
                method string
                resultType string = "complete"
            end
            r = prodserver.mcp.protocol.v20260728.cacheHints( ...
                struct('resultType', resultType, 'tools', {{}}), method);
        end

        function seedAppFlag(test)
        % Make this an app server: a definition file with the app flag.
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.applyFixture(PathFixture(tFolder.Folder));
            def.(MCPConstants.AppResourceVariable) = true;
            save(fullfile(tFolder.Folder, MCPConstants.DefinitionFile), ...
                "-struct", "def");
            % The definitions are cached; clear them now and afterwards.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function definitionResultsArePublic(test, definitionMethod)
            import prodserver.mcp.MCPConstants
            r = test.hinted(definitionMethod);
            test.verifyEqual(r.ttlMs, MCPConstants.DefinitionCacheTtlMs);
            test.verifyEqual(r.cacheScope, MCPConstants.DefinitionCacheScope);
        end

        function appToolsListIsNotCached(test)
            % An app server lists uri2json only to clients that support MCP
            % Apps, so its tools/list must not be shared between clients: a
            % public one could reach another client through a shared gateway.
            import prodserver.mcp.MCPConstants
            test.seedAppFlag();
            r = test.hinted("tools/list");
            test.verifyEqual(r.ttlMs, 0);
            test.verifyEqual(r.cacheScope, "private");
        end

        function appServerOtherListsArePublic(test)
            % Only tools/list depends on the client.
            import prodserver.mcp.MCPConstants
            test.seedAppFlag();
            for m = ["server/discover", "resources/list", "resources/templates/list"]
                r = test.hinted(m);
                test.verifyEqual(r.cacheScope, MCPConstants.DefinitionCacheScope, m);
                test.verifyEqual(r.ttlMs, MCPConstants.DefinitionCacheTtlMs, m);
            end
        end

        function resourceReadIsPrivate(test)
            % "private" is what the spec suggests for a resource that may
            % depend on the authenticated user. A wrongly public one could
            % be served across authorization contexts.
            import prodserver.mcp.MCPConstants
            r = test.hinted("resources/read");
            test.verifyEqual(r.ttlMs, MCPConstants.ResourceCacheTtlMs);
            test.verifyEqual(r.cacheScope, MCPConstants.ResourceCacheScope);
            test.verifyEqual(r.cacheScope, "private");
        end

        function uncachedMethodsGetNoHints(test, uncachedMethod)
            r = test.hinted(uncachedMethod);
            test.verifyFalse(isfield(r, 'ttlMs'));
            test.verifyFalse(isfield(r, 'cacheScope'));
        end

        function inputRequiredGetsNoHints(test, definitionMethod)
            % The spec: input_required results "are not cacheable and carry
            % no caching hints".
            r = test.hinted(definitionMethod, "input_required");
            test.verifyFalse(isfield(r, 'ttlMs'));
            test.verifyFalse(isfield(r, 'cacheScope'));
        end

        function missingResultTypeGetsNoHints(test)
            r = prodserver.mcp.protocol.v20260728.cacheHints( ...
                struct('tools', {{}}), "tools/list");
            test.verifyFalse(isfield(r, 'ttlMs'));
        end

        function methodCaseIsIgnored(test)
            r = test.hinted("Tools/List");
            test.verifyTrue(isfield(r, 'ttlMs'));
        end

        function constantsAreSchemaValid(test)
            % ttlMs has @minimum 0; cacheScope is "public" | "private".
            import prodserver.mcp.MCPConstants
            for t = [MCPConstants.DefinitionCacheTtlMs, ...
                    MCPConstants.ResourceCacheTtlMs, ...
                    MCPConstants.ClientDependentCacheTtlMs]
                test.verifyGreaterThanOrEqual(t, 0);
                test.verifyEqual(t, round(t));
            end
            test.verifyTrue(all(ismember([MCPConstants.DefinitionCacheScope, ...
                MCPConstants.ResourceCacheScope, ...
                MCPConstants.ClientDependentCacheScope], ["public", "private"])));
        end

        function hintsSurviveEncoding(test)
            % The field names need no translation on the way to JSON.
            import prodserver.mcp.MCPConstants
            r = test.hinted("tools/list");
            json = string(jsonencode(r));
            test.verifyTrue(contains(json, sprintf('"ttlMs":%d', ...
                MCPConstants.DefinitionCacheTtlMs)), json);
            test.verifyTrue(contains(json, sprintf('"cacheScope":"%s"', ...
                MCPConstants.DefinitionCacheScope)), json);
        end

    end
end
