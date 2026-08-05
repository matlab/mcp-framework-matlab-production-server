classdef tCatalog < matlab.unittest.TestCase
% Unit tests for prodserver.mcp.metrics.Catalog.
% Reads metrics from a fixture file rather than contacting a live server.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess=private)
        catalog
    end

    methods (TestClassSetup)

        function loadFixture(test)
            fixtureFile = fullfile(fileparts(mfilename("fullpath")), ...
                "metrics_fixture.txt");
            raw = string(fileread(fixtureFile));
            data = splitlines(raw);
            if strlength(data(end)) == 0
                data = data(1:end-1);
            end
            test.catalog = prodserver.mcp.metrics.Catalog(data, ...
                "http://localhost:9910/AlphaServer/mcp");
        end

    end

    methods (Test)

        % --- Constructor ---

        function constructorParsesAllMetrics(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.All);
            test.verifyNumElements(m, 27);
        end

        % --- name() tests ---

        function nameExactReturnsMatchingMetrics(test)
            m = test.catalog.name("MCP_Framework_Request");
            test.verifyNumElements(m, 5);
            for k = 1:numel(m)
                test.verifyEqual(m(k).name, "MCP_Framework_Request");
            end
        end

        function nameExactReturnsInstanceMetric(test)
            m = test.catalog.name("matlabprodserver_up_time_seconds");
            test.verifyNumElements(m, 1);
            test.verifyEqual(m.archive, "");
        end

        function nameExactNoMatchReturnsEmpty(test)
            m = test.catalog.name("nonexistent");
            test.verifyEmpty(m);
        end

        function nameContainsReturnsSubstringMatches(test)
            m = test.catalog.name("Request", match="Contains");
            test.verifyNumElements(m, 10);
        end

        function nameContainsReturnsInstanceMetrics(test)
            m = test.catalog.name("matlabprodserver_", match="Contains");
            test.verifyNumElements(m, 10);
        end

        function nameExactDistinguishesSimilarNames(test)
            m = test.catalog.name("MCP_AlphaServer_Request");
            test.verifyNumElements(m, 1);
        end

        % --- archive() tests ---

        function archiveExactReturnsAllMetricsForArchive(test)
            m = test.catalog.archive("AlphaServer");
            test.verifyNumElements(m, 3);
            for k = 1:numel(m)
                test.verifyEqual(m(k).archive, "AlphaServer");
            end
        end

        function archiveExactReturnsEmptyArchiveMetrics(test)
            m = test.catalog.archive("");
            test.verifyNumElements(m, 10);
            for k = 1:numel(m)
                test.verifyEqual(m(k).archive, "");
            end
        end

        function archiveExactNoMatchReturnsEmpty(test)
            m = test.catalog.archive("Nonexistent");
            test.verifyEmpty(m);
        end

        function archiveContainsReturnsSubstringMatches(test)
            m = test.catalog.archive("Server", match="Contains");
            test.verifyNumElements(m, 17);
        end

        function archiveContainsEmptyStringReturnsAll(test)
            m = test.catalog.archive("", match="Contains");
            test.verifyNumElements(m, 27);
        end

        function archiveExactDoesNotMatchSubstring(test)
            m = test.catalog.archive("Alpha");
            test.verifyEmpty(m);
        end

        % --- type() tests ---

        function typeCounterReturnsOnlyCounters(test)
            m = test.catalog.type(prodserver.mcp.metrics.Type.Counter);
            for k = 1:numel(m)
                test.verifyEqual(m(k).type, "counter");
            end
        end

        function typeGaugeReturnsOnlyGauges(test)
            m = test.catalog.type(prodserver.mcp.metrics.Type.Gauge);
            for k = 1:numel(m)
                test.verifyEqual(m(k).type, "gauge");
            end
        end

        function typeCounterCountMatchesExpected(test)
            m = test.catalog.type(prodserver.mcp.metrics.Type.Counter);
            test.verifyNumElements(m, 18);
        end

        function typeGaugeCountMatchesExpected(test)
            m = test.catalog.type(prodserver.mcp.metrics.Type.Gauge);
            test.verifyNumElements(m, 9);
        end

        function typeCounterIncludesInstanceMetrics(test)
            m = test.catalog.type(prodserver.mcp.metrics.Type.Counter);
            names = [m.name];
            test.verifyTrue(any(names == "matlabprodserver_up_time_seconds"));
        end

        function typeGaugeIncludesInstanceMetrics(test)
            m = test.catalog.type(prodserver.mcp.metrics.Type.Gauge);
            names = [m.name];
            test.verifyTrue(any(names == "matlabprodserver_memory_working_set_bytes"));
        end

        % --- scope() tests ---

        function scopeAllReturnsEverything(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.All);
            test.verifyNumElements(m, 27);
        end

        function scopeInstanceReturnsOnlyServerMetrics(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Instance);
            test.verifyNumElements(m, 10);
            for k = 1:numel(m)
                test.verifyTrue(startsWith(m(k).name, "matlabprodserver_"));
            end
        end

        function scopeMCPReturnsOnlyMCPMetrics(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.MCP);
            test.verifyNumElements(m, 12);
            for k = 1:numel(m)
                test.verifyTrue(startsWith(m(k).name, "MCP_"));
            end
        end

        function scopeServerReturnsOnlyServerMetrics(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Server);
            test.verifyNotEmpty(m);
            for k = 1:numel(m)
                test.verifyTrue( ...
                    contains(m(k).name, "_AlphaServer_"), ...
                    "Server scope metric should contain _AlphaServer_");
            end
        end

        function scopeToolReturnsOnlyToolCallMetrics(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Tool);
            test.verifyNotEmpty(m);
            for k = 1:numel(m)
                test.verifyTrue( ...
                    endsWith(m(k).name, "_Call"), ...
                    "Tool scope metric should end with _Call");
            end
        end

        % --- suffix tests ---

        function suffixParsedFromArchiveName(test)
            m = test.catalog.archive("AlphaServer");
            test.verifyNumElements(m, 3);
            for k = 1:numel(m)
                test.verifyEqual(m(k).suffix, "3");
            end
        end

        function suffixVariesByArchive(test)
            suffixes = string.empty;
            archives = ["AlphaServer","BetaServer","GammaServer",...
                "DeltaServer","EpsilonServer"];
            expected = ["3","1","2","5","4"];
            for k = 1:numel(archives)
                m = test.catalog.archive(archives(k));
                suffixes(k) = m(1).suffix;
            end
            test.verifyEqual(suffixes, expected);
        end

        function suffixEmptyForInstanceMetrics(test)
            m = test.catalog.name("matlabprodserver_up_time_seconds");
            test.verifyEmpty(m.suffix);
        end

        % --- filter() tests ---

        function filterByNameExact(test)
            m = test.catalog.filter(name="MCP_Framework_Request");
            test.verifyNumElements(m, 5);
            for k = 1:numel(m)
                test.verifyEqual(m(k).name, "MCP_Framework_Request");
            end
        end

        function filterByNameContains(test)
            m = test.catalog.filter(name="doWork", ...
                match="Contains");
            test.verifyNumElements(m, 2);
        end

        function filterByArchiveExact(test)
            m = test.catalog.filter(archive="BetaServer");
            test.verifyNumElements(m, 4);
            for k = 1:numel(m)
                test.verifyEqual(m(k).archive, "BetaServer");
            end
        end

        function filterByTypeCounter(test)
            m = test.catalog.filter( ...
                type=prodserver.mcp.metrics.Type.Counter);
            test.verifyNumElements(m, 18);
            for k = 1:numel(m)
                test.verifyEqual(m(k).type, "counter");
            end
        end

        function filterByTypeGauge(test)
            m = test.catalog.filter( ...
                type=prodserver.mcp.metrics.Type.Gauge);
            test.verifyNumElements(m, 9);
        end

        function filterCombinesNameAndArchive(test)
            m = test.catalog.filter(name="MCP_Framework_Request", ...
                archive="AlphaServer");
            test.verifyNumElements(m, 1);
            test.verifyEqual(m.name, "MCP_Framework_Request");
            test.verifyEqual(m.archive, "AlphaServer");
        end

        function filterCombinesArchiveAndType(test)
            m = test.catalog.filter(archive="EpsilonServer", ...
                type=prodserver.mcp.metrics.Type.Gauge);
            test.verifyNumElements(m, 2);
            for k = 1:numel(m)
                test.verifyEqual(m(k).archive, "EpsilonServer");
                test.verifyEqual(m(k).type, "gauge");
            end
        end

        function filterCombinesAllThreeCriteria(test)
            m = test.catalog.filter(name="MCP_Framework_Request", ...
                archive="GammaServer", ...
                type=prodserver.mcp.metrics.Type.Counter);
            test.verifyNumElements(m, 1);
            test.verifyEqual(m.value, 42);
        end

        function filterNoMatchReturnsEmpty(test)
            m = test.catalog.filter(name="nonexistent", ...
                archive="AlphaServer");
            test.verifyEmpty(m);
        end

        function filterWithContainsMatch(test)
            m = test.catalog.filter(name="Request", ...
                archive="Server", match="Contains");
            test.verifyNumElements(m, 10);
        end

        function filterWithNoOptionsReturnsAll(test)
            m = test.catalog.filter();
            test.verifyNumElements(m, 27);
        end

        % --- Value correctness ---

        function duplicateCounterPreservesAllValues(test)
            m = test.catalog.name("MCP_Framework_Request");
            test.verifyNumElements(m, 5);
            for k = 1:numel(m)
                test.verifyEqual(m(k).value, 42);
            end
        end

        function duplicateGaugePreservesAllValues(test)
            m = test.catalog.name("active_sessions");
            test.verifyNumElements(m, 2);
            values = sort([m.value]);
            test.verifyEqual(values, [2 7]);
        end

        function instanceMetricHasCorrectValue(test)
            m = test.catalog.name("matlabprodserver_requests_accepted_total");
            test.verifyNumElements(m, 1);
            test.verifyEqual(m.value, 47);
        end

    end
end
