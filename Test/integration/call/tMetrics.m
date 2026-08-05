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
            import prodserver.mcp.MCPConstants

            catalog = prodserver.mcp.metrics(test.endpoint);
            m = catalog.scope(prodserver.mcp.metrics.Scope.MCP);

            names = [m.name];
            test.verifyTrue( ...
                any(names == MCPConstants.MCPRequestMetric), ...
                "MCP scope missing framework request metric");

            entry = catalog.name(MCPConstants.MCPRequestMetric);
            test.verifyGreaterThan( ...
                entry(1).value, 0, ...
                "Framework request count should be positive");
        end

        function serverScopeFiltersToArchive(test)
        % Server scope should return only metrics matching the archive.
            catalog = prodserver.mcp.metrics(test.endpoint);
            m = catalog.archive(test.archive);

            test.verifyNotEmpty(m, ...
                "Archive filter returned no metrics");

            for k = 1:numel(m)
                test.verifyEqual(m(k).archive, test.archive, ...
                    "Metric archive should match " + test.archive);
            end
        end

        function allScopeIncludesInstanceMetrics(test)
        % All scope should include MPS instance-level metrics.
            catalog = prodserver.mcp.metrics(test.endpoint);
            m = catalog.scope(prodserver.mcp.metrics.Scope.All);

            names = [m.name];
            hasInstance = any(startsWith(names, "matlabprodserver_"));
            test.verifyTrue(hasInstance, ...
                "All scope should include matlabprodserver_ metrics");
        end

        function toolCallMetricIncrements(test)
        % Calling a tool should increment its call counter by exactly 1.
            import prodserver.mcp.MCPConstants

            toolMetric = MCPConstants.MCPMetricPrefix + ...
                test.toolName + MCPConstants.MCPToolCallSuffix;

            % Baseline
            catalog = prodserver.mcp.metrics(test.endpoint);
            entry = catalog.name(toolMetric);
            if isempty(entry)
                before = 0;
            else
                before = entry(1).value;
            end

            % Make one tool call
            prodserver.mcp.call(test.endpoint, test.toolName, 7);

            % After — poll until the metric increments (CI can be slow)
            after = before;
            for attempt = 1:10
                catalog = prodserver.mcp.metrics(test.endpoint);
                entry = catalog.name(toolMetric);
                test.assertNotEmpty(entry, ...
                    "Tool call metric should exist after call");
                after = entry(1).value;
                if after > before
                    break
                end
                pause(0.5);
            end

            test.verifyEqual(after, before + 1, ...
                "Tool call metric should increment by 1");
        end

        function duplicateToolNameAcrossArchivesRetainsCorrectValue(test)
        % Two archives with the same tool should not collide in
        % the parsed metrics.
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.TemporaryFolderFixture

            archiveA = "MetricsDupA";
            archiveZ = "MetricsDupZ";

            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, archiveA));
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, archiveZ));

            tfolderA = TemporaryFolderFixture;
            applyFixture(test, tfolderA);
            ctfA = prodserver.mcp.build(test.toolName, ...
                folder=tfolderA.Folder, archive=archiveA);
            endpointA = prodserver.mcp.deploy(ctfA, test.host, test.port);

            tfolderZ = TemporaryFolderFixture;
            applyFixture(test, tfolderZ);
            ctfZ = prodserver.mcp.build(test.toolName, ...
                folder=tfolderZ.Folder, archive=archiveZ);
            endpointZ = prodserver.mcp.deploy(ctfZ, test.host, test.port);

            % Call tool on archive A three times, archive Z once
            prodserver.mcp.call(endpointA, test.toolName, 1);
            prodserver.mcp.call(endpointA, test.toolName, 2);
            prodserver.mcp.call(endpointA, test.toolName, 3);
            prodserver.mcp.call(endpointZ, test.toolName, 4);

            toolMetric = MCPConstants.MCPMetricPrefix + ...
                test.toolName + MCPConstants.MCPToolCallSuffix;

            catalog = prodserver.mcp.metrics(endpointA);
            entry = catalog.name(toolMetric);
            entry = entry([entry.archive] == archiveA);
            test.verifyNotEmpty(entry, ...
                "Tool call metric should exist for archive A");
            test.verifyEqual(entry(1).value, 3, ...
                "Tool call metric should reflect calls to archive A (3), " + ...
                "not be overwritten by archive Z (1)");
        end

        function unreachableServerThrowsError(test)
        % Querying metrics from a server that refuses connections should
        % exhaust retries and throw ServerUnresponsive.
            test.verifyError( ...
                @() prodserver.mcp.metrics( ...
                    "http://localhost:1/fake/mcp", ...
                    retry=2, timeout=5, delay=0.1), ...
                "prodserver:mcp:ServerUnresponsive");
        end

    end
end
