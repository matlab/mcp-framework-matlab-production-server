classdef tAdapterFactory < matlab.unittest.TestCase
% Test Adapter.create static factory method.

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function clearCache(~)
            prodserver.mcp.client.Adapter.create(action="clearAll");
        end
    end

    methods (Test)

        function tExplicitV20250618ReturnsItsOwnAdapter(test)
            client = prodserver.mcp.client.Adapter.create( ...
                "http://localhost/mcp", protocol="2025-06-18");
            test.verifyClass(client, ...
                'prodserver.mcp.client.v20250618.Adapter');
            test.verifyEqual(client.Version, "2025-06-18");
        end

        function tExplicitV20260728ReturnsItsOwnAdapter(test)
            client = prodserver.mcp.client.Adapter.create( ...
                "http://localhost/mcp", protocol="2026-07-28");
            test.verifyClass(client, ...
                'prodserver.mcp.client.v20260728.Adapter');
            test.verifyEqual(client.Version, "2026-07-28");
        end

        function tInvalidVersionThrows(test)
            test.verifyError( ...
                @() prodserver.mcp.client.Adapter.create( ...
                    "http://localhost/mcp", protocol="9999-01-01"), ...
                "prodserver:mcp:UnsupportedProtocolVersion");
        end

        function tExplicitVersionReturnsFreshAdapter(test)
            c1 = prodserver.mcp.client.Adapter.create( ...
                "http://localhost/mcp", protocol="2026-07-28");
            c2 = prodserver.mcp.client.Adapter.create( ...
                "http://localhost/mcp", protocol="2026-07-28");
            test.verifyNotSameHandle(c1, c2);
        end

        function tClearRemovesEndpoint(test)
            ep = "http://localhost/mcp";
            prodserver.mcp.client.Adapter.create(ep, protocol="2025-06-18");

            prodserver.mcp.client.Adapter.create(ep, action="clear");

            result = prodserver.mcp.client.Adapter.create(ep, ...
                protocol="2026-07-28");
            test.verifyEqual(result.Version, "2026-07-28");
        end

        function tClearAllEmptiesCache(test)
            prodserver.mcp.client.Adapter.create( ...
                "http://host1/mcp", protocol="2025-06-18");
            prodserver.mcp.client.Adapter.create( ...
                "http://host2/mcp", protocol="2026-07-28");

            prodserver.mcp.client.Adapter.create(action="clearAll");

            c1 = prodserver.mcp.client.Adapter.create( ...
                "http://host1/mcp", protocol="2026-07-28");
            c2 = prodserver.mcp.client.Adapter.create( ...
                "http://host2/mcp", protocol="2025-06-18");
            test.verifyEqual(c1.Version, "2026-07-28");
            test.verifyEqual(c2.Version, "2025-06-18");
        end

        function tExplicitProtocolPopulatesCache(test)
            ep = "http://localhost/mcp";
            prodserver.mcp.client.Adapter.create(ep, protocol="2026-07-28");
            c = prodserver.mcp.client.Adapter.create(ep, protocol="discover");
            test.verifyEqual(c.Version, "2026-07-28");
        end

        function tInvalidVersionDoesNotPoisonCache(test)
            ep = "http://localhost/mcp";
            prodserver.mcp.client.Adapter.create(ep, protocol="2026-07-28");
            test.verifyError( ...
                @() prodserver.mcp.client.Adapter.create( ...
                    ep, protocol="2024-11-05"), ...
                "prodserver:mcp:UnsupportedProtocolVersion");
            c = prodserver.mcp.client.Adapter.create(ep, protocol="discover");
            test.verifyEqual(c.Version, "2026-07-28");
        end

        function tClearReturnsEmpty(test)
            result = prodserver.mcp.client.Adapter.create( ...
                "http://localhost/mcp", action="clear");
            test.verifyEmpty(result);
        end

        function tClearAllReturnsEmpty(test)
            result = prodserver.mcp.client.Adapter.create(action="clearAll");
            test.verifyEmpty(result);
        end

    end

end
