classdef tMetrics < MCPCaller
% Integration test for prodserver.mcp.metrics against a live MPS instance.
% Requires MW_MCP_MPS_TEST_SERVER to point to a running server.

% Copyright 2026 The MathWorks, Inc.

    properties
        endpoint
        archive
        toolName
    end

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);
            setFolders(test, temp=tfolder.Folder);
        end
    end

    methods (TestClassSetup)

        function buildAndDeploy(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            test.archive = "MetricsIntTest";
            test.toolName = "toyScalarOne";

            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, test.archive));

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);

            ctf = prodserver.mcp.build(test.toolName, ...
                folder=tfolder.Folder, ...
                archive=test.archive);
            test.assertNotEmpty(ctf);

            test.endpoint = prodserver.mcp.deploy( ...
                ctf, test.host, test.port);

            % Make one call so that server and tool metrics are populated.
            prodserver.mcp.call(test.endpoint, test.toolName, 42);
        end

    end

    methods (Test)

        function mcpScopeReturnsFrameworkMetric(test)
        % MCP scope should include the framework request counter.
            import prodserver.mcp.MetricsScope
            import prodserver.mcp.MCPConstants

            m = prodserver.mcp.metrics(test.endpoint, MetricsScope.MCP);

            test.verifyTrue( ...
                isfield(m, MCPConstants.MCPRequestMetric), ...
                "MCP scope missing framework request metric");
            test.verifyGreaterThan( ...
                m.(MCPConstants.MCPRequestMetric).value, 0, ...
                "Framework request count should be positive");
        end

        function serverScopeFiltersToArchive(test)
        % Server scope should return only metrics matching the archive.
            import prodserver.mcp.MetricsScope
            import prodserver.mcp.MCPConstants

            m = prodserver.mcp.metrics(test.endpoint, MetricsScope.Server);

            fields = string(fieldnames(m));
            test.verifyNotEmpty(fields, ...
                "Server scope returned no metrics");

            for k = 1:numel(fields)
                test.verifyTrue( ...
                    contains(fields(k), test.archive), ...
                    "Metric " + fields(k) + ...
                    " should contain archive name " + test.archive);
            end
        end

        function allScopeIncludesInstanceMetrics(test)
        % All scope should include MPS instance-level metrics.
            import prodserver.mcp.MetricsScope

            m = prodserver.mcp.metrics(test.endpoint, MetricsScope.All);

            fields = string(fieldnames(m));
            hasInstance = any(startsWith(fields, "matlabprodserver_"));
            test.verifyTrue(hasInstance, ...
                "All scope should include matlabprodserver_ metrics");
        end

        function toolCallMetricIncrements(test)
        % Calling a tool should increment its call counter by exactly 1.
            import prodserver.mcp.MetricsScope
            import prodserver.mcp.MCPConstants

            toolMetric = MCPConstants.MCPMetricPrefix + ...
                test.toolName + MCPConstants.MCPToolCallSuffix;

            % Baseline
            m1 = prodserver.mcp.metrics(test.endpoint, MetricsScope.MCP);
            if isfield(m1, toolMetric)
                before = m1.(toolMetric).value;
            else
                before = 0;
            end

            % Make one tool call
            prodserver.mcp.call(test.endpoint, test.toolName, 7);

            % After — poll until the metric increments (CI can be slow)
            after = before;
            for attempt = 1:10
                m2 = prodserver.mcp.metrics(test.endpoint, MetricsScope.MCP);
                test.assertTrue(isfield(m2, toolMetric), ...
                    "Tool call metric should exist after call");
                after = m2.(toolMetric).value;
                if after > before
                    break
                end
                pause(0.5);
            end

            test.verifyEqual(after, before + 1, ...
                "Tool call metric should increment by 1");
        end

        function unreachableServerThrowsError(test)
        % Querying metrics from a server that refuses connections should
        % exhaust retries and throw ServerUnresponsive.
            import prodserver.mcp.MetricsScope

            test.verifyError( ...
                @() prodserver.mcp.metrics( ...
                    "http://localhost:1/fake/mcp", ...
                    MetricsScope.MCP, retry=2, timeout=5, delay=0.1), ...
                "prodserver:mcp:ServerUnresponsive");
        end

    end
end
