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

        function scopeServerReturnsEachArchivesOwnCounters(test)
            % MCP_<archive>_Request for each of the five archives: a kind,
            % from every archive, whichever the endpoint names.
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Server);
            test.verifyNumElements(m, 5);
            test.verifyEqual(sort([m.name]), sort("MCP_" + ...
                ["Alpha" "Beta" "Gamma" "Delta" "Epsilon"] + "Server_Request"));
        end

        function scopeToolReturnsEveryToolCounter(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Tool);
            test.verifyEqual([m.name], ["MCP_doWork_Call" "MCP_doWork_Call"]);
        end

        function scopeFrameworkReturnsEachArchivesRow(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Framework);
            test.verifyNumElements(m, 5);
            test.verifyEqual(unique([m.name]), "MCP_Framework_Request");
        end

        function scopeCustomReturnsTheRest(test)
            m = test.catalog.scope(prodserver.mcp.metrics.Scope.Custom);
            test.verifyEqual(unique([m.name]), ...
                ["active_sessions" "memory_usage_bytes" "queue_depth"]);
            test.verifyNumElements(m, 5);
        end

        function kindsDontOverlap(test)
            % All is Instance, MCP and Custom; MCP is Framework, Server and
            % Tool. Each metric is of exactly one kind at each level.
            for c = {test.catalog, fooCatalog()}
                test.verifyPartition(c{1}, prodserver.mcp.metrics.Scope.All, ...
                    ["Instance" "MCP" "Custom"]);
                test.verifyPartition(c{1}, prodserver.mcp.metrics.Scope.MCP, ...
                    ["Framework" "Server" "Tool"]);
            end
        end

        % --- Scopes of archives whose names share a prefix ---
        %
        % Scope.Server matched names containing _<archive>_, so foo's took
        % in foo_bar's metrics, and none of foo's tool counters unless a
        % tool shared the archive's name.

        function serverScopeKeepsArchivesApart(test)
            m = fooCatalog().scope(prodserver.mcp.metrics.Scope.Server);
            test.verifyEqual(sort([m.name] + "{" + [m.archive] + "}"), ...
                sort(["MCP_foo_Request{foo}" "MCP_foo_ElapsedTime{foo}" ...
                "MCP_foo_bar_Request{foo_bar}" "MCP_foo_bar_ElapsedTime{foo_bar}"]));
        end

        function toolScopeHasEveryToolCounter(test)
            % Calls, rejections and refusals, and their per-revision counts.
            m = fooCatalog().scope(prodserver.mcp.metrics.Scope.Tool);
            test.verifyEqual(sort([m.name]), sort(["MCP_foo_Call" ...
                "MCP_foo_Call_2026_07_28" "MCP_foo_Rejected" ...
                "MCP_foo_Rejected_2026_07_28" "MCP_uri2json_Refused" ...
                "MCP_foo_bar_Call" "MCP_foo_bar_Call_2026_07_28"]));
        end

        function customScopeHasMCPLookalikes(test)
            % A name starting MCP_ that is of no MCP kind is custom.
            m = fooCatalog().scope(prodserver.mcp.metrics.Scope.Custom);
            test.verifyEqual(sort([m.name]), ["MCP_mine" "foo_custom_count"]);
        end

        function filterScopeAndArchive(test)
            % One archive's metrics of one kind.
            c = fooCatalog();
            m = c.filter(scope=prodserver.mcp.metrics.Scope.Server, archive="foo");
            test.verifyEqual(sort([m.name]), ...
                ["MCP_foo_ElapsedTime" "MCP_foo_Request"]);
            m = c.filter(scope=prodserver.mcp.metrics.Scope.Tool, archive="foo_bar");
            test.verifyEqual(sort([m.name]), ...
                ["MCP_foo_bar_Call" "MCP_foo_bar_Call_2026_07_28"]);
        end

        function labelsOtherThanArchive(test)
            % A metric whose labels name no archive has archive "", as one
            % with no labels does. One with too few made every scope, and
            % the display, fail: they line up all the metrics' archives.
            rows = [
                "counter" "http_requests{method=""GET""} 3"
                "counter" "probe{myarchive=""zz_4""} 1"
                "counter" "custom{archive=""plain""} 2"
                "counter" "MCP_two_Request{method=""x"",archive=""two_7""} 5"
                "counter" "matlabprodserver_up_time_seconds 9"
                ];
            name = extractBefore(rows(:,2), "{" | " ");
            data = reshape(["# TYPE " + name + " " + rows(:,1), rows(:,2)]', [], 1);
            c = prodserver.mcp.metrics.Catalog(data, "http://localhost:9910/two/mcp");

            all = c.scope(prodserver.mcp.metrics.Scope.All);
            test.verifyNumElements(all, 5);
            test.verifyEqual([all.archive], ["" "" "plain" "two" ""], ...
                "myarchive isn't an archive label; archive needn't be first.");
            test.verifyEqual([c.scope(prodserver.mcp.metrics.Scope.Server).name], ...
                "MCP_two_Request");
            test.verifyEqual(sort([c.scope(prodserver.mcp.metrics.Scope.Custom).name]), ...
                ["custom" "http_requests" "probe"]);
            % An archive with no deployment suffix has none, which the
            % suffix filter reads as NaN.
            plain = c.archive("plain");
            test.verifyEmpty(plain.suffix);
            test.verifyEqual([c.filter(archive="plain", suffix=NaN).name], "custom");
            test.verifyEqual([c.filter(suffix=7).name], "MCP_two_Request");
            out = string(evalc("disp(c)"));
            test.verifySubstring(out, "of 5 metrics");
        end

        function filterScopeAllSelectsEverything(test)
            test.verifyNumElements( ...
                test.catalog.filter(scope=prodserver.mcp.metrics.Scope.All), 27);
        end

        % --- Plain server address (no /<archive>/mcp) ---

        function plainAddressParsesAllMetrics(test)
        % metrics() accepts a plain server address, so the catalog must too.
        % No scope depends on the address.
            c = prodserver.mcp.metrics.Catalog(fixtureData(), ...
                "http://localhost:9910/");
            test.verifyNumElements(c.scope(prodserver.mcp.metrics.Scope.All), 27);
            test.verifyNumElements(c.scope(prodserver.mcp.metrics.Scope.MCP), 12);
            test.verifyNumElements(c.scope(prodserver.mcp.metrics.Scope.Server), 5);
            test.verifyNumElements(c.scope(prodserver.mcp.metrics.Scope.Tool), 2);
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

    methods (Test)

        % --- Display ---
        %
        % The properties are protected, so MATLAB's own display said
        % "Catalog with no properties", and a user took a full catalog
        % for an empty one.

        function displaySummarises(test)
            c = test.catalog; %#ok<NASGU>
            out = string(evalc("disp(c)"));
            test.verifySubstring(out, "of 27 metrics");
            test.verifySubstring(out, "http://localhost:9910");
            test.verifySubstring(out, "for archive AlphaServer");
            test.verifySubstring(out, "doWork 8", ...
                "A tool's calls are summed over the archives that report them.");
            test.verifySubstring(out, "Query it with");
            test.verifyFalse(contains(out, "no properties"));
        end

        function displayHasNoUserInformation(test)
            c = prodserver.mcp.metrics.Catalog(fixtureData(), ...
                "http://jdoe:secret@localhost:9910/AlphaServer/mcp"); %#ok<NASGU>
            out = string(evalc("disp(c)"));
            test.verifyFalse(contains(out, "secret") || contains(out, "jdoe"), out);
            test.verifySubstring(out, "http://localhost:9910");
        end

        function displayEmptyCatalog(test)
            c = prodserver.mcp.metrics.Catalog(string.empty, ...
                "http://localhost:9910"); %#ok<NASGU>
            out = string(evalc("disp(c)"));
            test.verifySubstring(out, "with no metrics");
        end

        function displayListsFirstFewTools(test)
            tools = "tool" + (1:6);
            data = reshape(["# TYPE MCP_" + tools + "_Call counter"; ...
                "MCP_" + tools + "_Call{archive=""A""} 1"], [], 1);
            c = prodserver.mcp.metrics.Catalog(data, ...
                "http://localhost:9910/A/mcp"); %#ok<NASGU>
            out = string(evalc("disp(c)"));
            test.verifySubstring(out, "6 tool(s) called");
            test.verifySubstring(out, "tool1 1");
            test.verifySubstring(out, ", ...");
            test.verifyFalse(contains(out, "tool6"), "Only the first few.");
        end

        function displayCountsOnlyCalls(test)
            % Scope.Tool has the rejections and per-revision counts too,
            % which the tool line mustn't add to the calls.
            c = fooCatalog(); %#ok<NASGU>
            out = string(evalc("disp(c)"));
            test.verifySubstring(out, "foo 20, foo_bar 2");
        end

    end

    methods (Access=private)

        function verifyPartition(test, c, whole, parts)
        % The metrics of kind WHOLE are those of PARTS, each in one only.
            names = @(s) [c.scope(s).name] + "{" + [c.scope(s).archive] + "}";
            joined = string.empty;
            for p = parts
                joined = [joined names(prodserver.mcp.metrics.Scope(p))]; %#ok<AGROW>
            end
            test.verifyEqual(sort(joined), sort(names(whole)), ...
                string(whole) + " is " + strjoin(parts, ", ") + ".");
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

function c = fooCatalog()
% Archives foo and foo_bar, whose names share a prefix, each with a tool
% of its own name: the bug report's server. foo also serves an MCP App.
    rows = [
        "counter" "MCP_Framework_Request{archive=""foo_17""} 26"
        "counter" "MCP_foo_Request{archive=""foo_17""} 26"
        "counter" "MCP_foo_ElapsedTime{archive=""foo_17""} 1.5"
        "counter" "MCP_foo_Call{archive=""foo_17""} 20"
        "counter" "MCP_foo_Call_2026_07_28{archive=""foo_17""} 20"
        "counter" "MCP_foo_Rejected{archive=""foo_17""} 3"
        "counter" "MCP_foo_Rejected_2026_07_28{archive=""foo_17""} 3"
        "counter" "MCP_uri2json_Refused{archive=""foo_17""} 1"
        "counter" "foo_custom_count{archive=""foo_17""} 4"
        "counter" "MCP_mine{archive=""foo_17""} 5"
        "counter" "MCP_Framework_Request{archive=""foo_bar_18""} 2"
        "counter" "MCP_foo_bar_Request{archive=""foo_bar_18""} 2"
        "counter" "MCP_foo_bar_ElapsedTime{archive=""foo_bar_18""} 0.2"
        "counter" "MCP_foo_bar_Call{archive=""foo_bar_18""} 2"
        "counter" "MCP_foo_bar_Call_2026_07_28{archive=""foo_bar_18""} 2"
        "counter" "matlabprodserver_up_time_seconds 100"
        ];
    metric = extractBefore(rows(:,2), "{" | " ");
    data = reshape(["# TYPE " + metric + " " + rows(:,1), rows(:,2)]', [], 1);
    c = prodserver.mcp.metrics.Catalog(data, "http://localhost:9910/foo/mcp");
end
