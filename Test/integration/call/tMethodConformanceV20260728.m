classdef tMethodConformanceV20260728 < tMethodConformance
%tMethodConformanceV20260728 MCP method conformance for revision 2026-07-28.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Protocol = "2026-07-28"

        % 2026-07-28 returns an unknown/unimplemented method as HTTP 404.
        MethodNotFoundHttpStatus double = 404
    end

    methods (Test)

        function tPing(test)
        % ping was removed in 2026-07-28 (changelog major #5), so it must be
        % rejected as Method not found rather than returning an empty result.
            resp = test.rawRequest("ping");
            test.verifyMethodNotFound(resp, "ping");
        end

        function tServerDiscover(test)
        % server/discover is the 2026-07-28 discovery mechanism and must
        % return the server capabilities and supported protocol versions.
            resp = test.rawRequest("server/discover");
            test.verifyOkResult(resp, "server/discover", "capabilities");
        end

        function tCacheableResultsCarryHints(test)
        % Every result in this revision MUST carry resultType, and the
        % CacheableResult ones MUST also carry ttlMs and cacheScope.
        % The shared verifyOkResult checks none of the three, which is how
        % G2 went unnoticed.
            import prodserver.mcp.internal.hasField
            for m = ["server/discover", "tools/list", "resources/list", ...
                    "resources/templates/list"]
                resp = test.rawRequest(m);
                test.verifyOkResult(resp, m);
                ctx = m + " [" + test.describe(resp) + "]";
                test.assertTrue(hasField(resp, "Body.Data.result"), ctx);
                r = resp.Body.Data.result;
                test.verifyEqual(string(r.resultType), "complete", ctx);
                test.verifyTrue(isfield(r, "ttlMs") && isnumeric(r.ttlMs) ...
                    && r.ttlMs >= 0, ctx + ": ttlMs missing or invalid");
                test.verifyTrue(isfield(r, "cacheScope") && ...
                    ismember(string(r.cacheScope), ["public", "private"]), ...
                    ctx + ": cacheScope missing or invalid");
            end
        end

        function tToolCallCarriesNoCacheHints(test)
        % resultType yes, since every result needs it. Caching hints no:
        % CallToolResult is not a CacheableResult.
            resp = test.rawRequest("tools/call", struct("name", ...
                test.ToolName, "arguments", struct("n", 5, ...
                "type", "Eisenstein")));
            ctx = " [" + test.describe(resp) + "]";
            test.assertTrue(prodserver.mcp.internal.hasField(resp, ...
                "Body.Data.result"), "tools/call failed" + ctx);
            r = resp.Body.Data.result;
            test.verifyEqual(string(r.resultType), "complete", ctx);
            test.verifyFalse(isfield(r, "ttlMs"), ctx);
            test.verifyFalse(isfield(r, "cacheScope"), ctx);
        end

        function tProbeResolvesThisRevision(test)
        % protocol="discover" against a real, strictly-validating server
        % must land on 2026-07-28. Every other test in this file is handed
        % the revision through protocol=test.Protocol, so none of them
        % exercises the probe -- and the probe is the one request the
        % framework sends before it knows which revision it is speaking.
        %
        % The failure this guards is silent. probe() reads "no result
        % member" as "this server does not speak 2026-07-28" and falls back
        % to 2025-06-18, so a probe missing a header the server requires
        % gets a 400, is misread as a negative answer, and downgrades the
        % client against a server that would have answered. Nothing throws;
        % the whole suite simply tests the older revision twice. That is
        % exactly what a hand-built probe envelope caused, and why the
        % probe now builds its request through the adapter.
            prodserver.mcp.client.Adapter.create(test.Endpoint, ...
                action="clear");
            client = prodserver.mcp.client.Adapter.create(test.Endpoint, ...
                protocol="discover");
            test.verifyEqual(client.Version, "2026-07-28", ...
                "probe fell back to " + client.Version + "; a 2026-07-28 " + ...
                "server/discover was rejected or returned no result");
            test.verifyClass(client, ...
                'prodserver.mcp.client.v20260728.Adapter');
        end

    end

end
