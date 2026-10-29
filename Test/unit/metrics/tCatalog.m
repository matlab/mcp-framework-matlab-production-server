classdef tCatalog < matlab.unittest.TestCase
% Unit tests for prodserver.mcp.metrics.Catalog.
% Reads metrics from a fixture file rather than contacting a live server.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess=private)
        catalog
    end

    methods (TestClassSetup)

        function loadFixture(test)
            test.catalog = prodserver.mcp.metrics.Catalog(fixtureData(), ...
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

        % --- Plain server address (no /<archive>/mcp) ---

        function plainAddressParsesAllMetrics(test)
        % metrics() accepts a plain server address, so the catalog must too.
            c = prodserver.mcp.metrics.Catalog(fixtureData(), ...
                "http://localhost:9910");
            test.verifyNumElements(c.scope(prodserver.mcp.metrics.Scope.All), 27);
            test.verifyNotEmpty(c.scope(prodserver.mcp.metrics.Scope.MCP));
            test.verifyNotEmpty(c.scope(prodserver.mcp.metrics.Scope.Tool));
        end

        function plainAddressServerScopeErrors(test)
        % No archive name to match on, so Scope.Server can't be answered.
            c = prodserver.mcp.metrics.Catalog(fixtureData(), ...
                "http://localhost:9910/");
            test.verifyError( ...
                @() c.scope(prodserver.mcp.metrics.Scope.Server), ...
                "prodserver:mcp:NoServerScope");
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

        function nanReturnsUnsuffixedMetrics(test)
            m = test.catalog.filter(suffix=NaN);
            test.verifyNumElements(m, 10);
            test.verifyTrue(all(arrayfun(@(metric) isempty(metric.suffix), m)));
        end

        function badSuffixType(test)
            test.verifyError(@()test.catalog.filter(suffix={1,3,4}), ...
                "prodserver:mcp:InvalidMetricsSuffix");

            s.x = 1; s.y = 2; s.z = 3;
            test.verifyError(@()test.catalog.filter(suffix=s), ...
                "prodserver:mcp:InvalidMetricsSuffix");

            test.verifyError(@()test.catalog.filter(suffix=@(x)"BadSuffix"), ...
                "prodserver:mcp:InvalidMetricsSuffix");

            test.verifyError(@()test.catalog.filter(suffix=@(x)error("BadSuffix")), ...
                "prodserver:mcp:MetricsSuffixFunctionFailed");

            test.verifyError(@()test.catalog.filter(suffix="x"), ...
                "prodserver:mcp:InvalidTextMetricsSuffix");
        end

        function invalidMetricsMask(test)
            test.verifyError(@()test.catalog.filter(suffix=@(s) true), ...
                "prodserver:mcp:InvalidMetricsMaskSize");
        end

        function filterBySuffixRejectsInvalidFunctionHandle(test)
            test.verifyError(@()test.catalog.filter(suffix=@()1), ...
                "prodserver:mcp:InvalidMetricsSuffixFunction");
            test.verifyError(@()test.catalog.filter(suffix=@not_a_function), ...
                "prodserver:mcp:NonExistentMetricsSuffixFunction");
        end

        function predicateSuffix(test)
            % Metrics from Delta and Epsilon servers
            m = test.catalog.filter(suffix=@(s)s > 3);
            test.verifyEqual(unique([m.archive]), ["DeltaServer","EpsilonServer"]);
        end

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

        function filterBySuffixReturnsAllMetricsWithThatSuffix(test)
            % AlphaServer has 3 metrics, all suffix "3". 
            m = test.catalog.filter(suffix="3");
            test.verifyNumElements(m, 3);
            test.verifyEqual(unique([m.archive]), "AlphaServer");
        end

        function filterBySuffixAcceptsDouble(test)
            % str2double(3) is NaN, so this currently returns nothing.
            m = test.catalog.filter(suffix=3);
            test.verifyNumElements(m, 3);
        end

        function filterBySuffixFunctionHandle(test)
            % @max selects DeltaServer (suffix 5), every one of its metrics.
            m = test.catalog.filter(suffix=@max);
            test.verifyNotEmpty(m);
            test.verifyEqual(unique([m.archive]), "DeltaServer");
            test.verifyNumElements(m, numel(test.catalog.archive("DeltaServer")));
        end

        function filterBySuffixIgnoresUnsuffixedMetrics(test)
            % 10 instance metrics have [] suffixes
            m = test.catalog.filter(suffix="1");
            test.verifyEqual(unique([m.archive]), "BetaServer");
            test.verifyNumElements(m, 4);
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

function data = fixtureData()
    fixtureFile = fullfile(fileparts(mfilename("fullpath")), ...
        "metrics_fixture.txt");
    raw = string(fileread(fixtureFile));
    data = splitlines(raw);
    if strlength(data(end)) == 0
        data = data(1:end-1);
    end
end
