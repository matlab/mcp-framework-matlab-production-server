classdef tArchiveCachePerformance < matlab.perftest.TestCase
% The steady-state costs the foundation promises: an archive-scope
% archiveCache get, at most 20 microseconds, and a request's
% beginRequest plus setContext, under 10, on R2026b; and startLogContext,
% what each request pays to start its log context, at most 40 on a
% realistic tools/call: 27.6 to 35.8 measured in an MPS worker (FA-29).
% Log.instance() is reported without a bound.
%
% Run on its own, not in the unit suite: a timing on a busy machine is a
% measurement, not a pass/fail test.
%     results = runperf("Test/performance/tArchiveCachePerformance.m");
%     sampleSummary(results)
% Each sample times a loop of N calls, so the loop's own cost is small and
% the sample divided by N is one call's cost, as spike S5 measured it
% (FD-16). keepMeasuring's own overhead, a few microseconds a call, would
% otherwise be counted. checkBounds below reads the medians.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Name = "tArchiveCachePerformanceProbe"
        N = 10000
    end

    methods (TestMethodSetup)
        function warm(test)
            import prodserver.mcp.handler.archiveCache
            archiveCache(test.Name, action="set", value=struct("tools", {repmat({struct("name", "x")}, 1, 20)}));
            archiveCache(test.Name);
            prodserver.mcp.logging.Log.instance();
            test.addTeardown(@() archiveCache(test.Name, action="clear"));
        end
    end

    methods (Test)

        function archiveScopeGetIsFast(test)
            name = test.Name;
            test.startMeasuring();
            for k = 1:test.N
                prodserver.mcp.handler.archiveCache(name);
            end
            test.stopMeasuring();
        end

        function largeValueGetIsAsFast(test)
            % A 200-tool definition struct: the cost must not grow with the
            % value (a dictionary of the values themselves took 180 us).
            import prodserver.mcp.handler.archiveCache
            big = struct("tools", {repmat({struct("name", "x", "inputSchema", ...
                struct("a", 1:100))}, 1, 200)});
            name = test.Name + "Large";
            archiveCache(name, action="set", value=big);
            test.addTeardown(@() archiveCache(name, action="clear"));
            test.startMeasuring();
            for k = 1:test.N
                archiveCache(name);
            end
            test.stopMeasuring();
        end

        function logInstanceIsOneLookup(test)
            % Not bounded by a requirement; reported, because tracing's Off
            % path calls it on every request.
            test.startMeasuring();
            for k = 1:test.N
                prodserver.mcp.logging.Log.instance();
            end
            test.stopMeasuring();
        end

        function requestContextCost(test)
            % startLogContext on a tools/call as Claude Code sends it: the
            % trace in a header only.
            [request, jrpc] = tArchiveCachePerformance.toolsCall(false);
            timeStartLogContext(test, request, jrpc);
        end

        function requestContextCostWithMeta(test)
            % The same, with params._meta.traceparent as well.
            [request, jrpc] = tArchiveCachePerformance.toolsCall(true);
            timeStartLogContext(test, request, jrpc);
        end

        function beginRequestAndSetContextAreFast(test)
            log = prodserver.mcp.logging.Log(instanceRoot="", archive="a_1");
            jrpc = struct("jsonrpc", "2.0", "id", 7, "method", "tools/call");
            handle = @() [];
            test.startMeasuring();
            for k = 1:test.N
                log.beginRequest(jrpc);
                log.setContext(trace=handle);
            end
            test.stopMeasuring();
        end
    end

    methods (Access = private)
        function timeStartLogContext(test, request, jrpc)
            log = prodserver.mcp.logging.Log(instanceRoot="", archive="a_1");
            test.startMeasuring();
            for k = 1:test.N
                prodserver.mcp.internal.startLogContext(log, request, jrpc);
            end
            test.stopMeasuring();
        end
    end

    methods (Static)
        function [request, jrpc] = toolsCall(withMeta)
        %toolsCall A tools/call with ten headers like Claude Code's, an
        %   800-character Authorization among them, and the trace in a
        %   header; WITHMETA puts it in params._meta too.
            tp = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';
            request = struct("Method", "POST", "Headers", {{ ...
                'Host', 'localhost:9910'; 'User-Agent', 'claude-code/2.1'; ...
                'Accept', 'application/json, text/event-stream'; ...
                'Content-Type', 'application/json'; 'Content-Length', '180'; ...
                'Authorization', ['Bearer ' repmat('x', 1, 793)]; ...
                'MCP-Protocol-Version', '2026-07-28'; 'Mcp-Method', 'tools/call'; ...
                'Mcp-Name', 'cleanSignal'; 'traceparent', tp}});
            meta = struct("protocolVersion", "2026-07-28");
            if withMeta
                meta.traceparent = tp;
            end
            jrpc = struct("jsonrpc", "2.0", "id", 7, "method", "tools/call", "params", ...
                struct("name", "cleanSignal", "arguments", struct("x", 1), "x_meta", meta));
        end

        function ok = checkBounds(results)
        %checkBounds True when each median is within its bound (microseconds).
            bounds = dictionary(["archiveScopeGetIsFast", "largeValueGetIsAsFast", ...
                "beginRequestAndSetContextAreFast", "logInstanceIsOneLookup", ...
                "requestContextCost", "requestContextCostWithMeta"], [20 20 10 Inf 40 40]);
            ok = true;
            for r = results
                name = string(extractAfter(r.Name, "/"));
                us = 1e6 * median(r.Samples.MeasuredTime) / tArchiveCachePerformance.N;
                within = us <= bounds(name);
                fprintf("%-36s median %6.2f us, bound %d us: %s\n", name, us, bounds(name), ...
                    string(within));
                ok = ok && within;
            end
        end
    end
end
