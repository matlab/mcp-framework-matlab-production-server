classdef tLog < matlab.unittest.TestCase
% prodserver.mcp.logging.Log: the line format, the threshold, the request
% context, the throttle and the rule that logging never raises.

% Copyright 2026 The MathWorks, Inc.

    properties
        Captured    % LogCapture
    end

    properties (Constant)
        Event = "prodserver:mcp:RequestCancelled"
        TP = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    end

    methods (TestMethodSetup)
        function reset(test)
            test.Captured = test.applyFixture(prodserver.mcp.test.mixin.LogCapture());
        end
    end

    methods (Test)

        function lineFormatHasLevelIdContextAndMessage(test)
            log = make(test, "cleanSignal_3");
            log.beginRequest(struct("id", 7));
            log.setContext(tool="cleanSignal");
            log.log(prodserver.mcp.logging.Level.Warning, "prodserver:mcp:TracingEnabled", "hello %d", 5);
            test.verifyEqual(test.Captured.Lines, "[mcp:warning] prodserver:mcp:TracingEnabled id=7 " + ...
                "archive=cleanSignal_3 tool=cleanSignal hello 5");
        end

        function emptyContextHasNoExtraSpace(test)
            log = make(test, "");
            log.log("Information", test.Event, "msg");
            test.verifyEqual(test.Captured.Lines, "[mcp:information] " + test.Event + " msg");
        end

        function contextFieldsAppearInFixedOrder(test)
            log = make(test, "a_1");
            log.beginRequest(struct("id", "r"));
            log.setContext(tool="t");
            log.setContext(trace=valid(test));
            log.log("Information", test.Event, "m");
            test.verifyEqual(test.Captured.Lines, "[mcp:information] " + test.Event + ...
                " id=r trace=" + test.TP + " archive=a_1 tool=t m");
        end

        function emptyStringIdIsShown(test)
        % "" is a valid id, so the line names it; null and no id don't.
            cases = {struct("id", ''), "id="""" "; ...
                struct("id", ""), "id="""" "; ...
                struct("id", []), ""; ...
                struct("method", "x"), ""};
            for n = 1:size(cases, 1)
                log = make(test, "a_1");
                log.beginRequest(cases{n,1});
                log.log("Information", test.Event, "m");
                line = test.Captured.Lines(end);
                if strlength(cases{n,2}) > 0
                    test.verifySubstring(line, cases{n,2}, string(n));
                else
                    test.verifyFalse(contains(line, "id="), string(n));
                end
            end
        end

        function newlinesAreEscaped(test)
            log = make(test, "");
            log.log("Error", test.Event, "one" + newline + "two" + newline);
            test.verifyNumElements(test.Captured.Lines, 1);
            test.verifySubstring(test.Captured.Lines, "one\ntwo\n");
            test.verifyFalse(contains(test.Captured.Lines, newline));
        end

        function warningAndErrorGoToStderr(test)
            log = make(test, "");
            log.Threshold = "Trace";
            for lvl = ["Trace", "Information", "Warning", "Error"]
                log.log(lvl, test.Event, lvl);
            end
            test.verifyEqual(test.Captured.Streams', [1 1 2 2]);
        end

        function thresholdComesFromMainConfig(test)
            root = instanceWith(test, ["# --log-severity trace", "--log-severity trace", ...
                "--log-severity Warning"]);
            log = prodserver.mcp.logging.Log(instanceRoot=root, archive="", sink=test.Captured.sink());
            test.verifyEqual(log.level(), prodserver.mcp.logging.Level.Warning, "the last line wins");
            log.log("Information", test.Event, "dropped");
            log.log("Warning", test.Event, "kept");
            test.verifyEqual(test.Captured.Lines, "[mcp:warning] " + test.Event + " kept");
        end

        function badLogSeverityLogsOnceAndUsesInformation(test)
            root = instanceWith(test, "--log-severity loud");
            for k = 1:2
                log = prodserver.mcp.logging.Log(instanceRoot=root, archive="", sink=test.Captured.sink());
                test.verifyEqual(log.level(), prodserver.mcp.logging.Level.Information);
            end
            test.verifyNumElements(test.Captured.Lines, 2, "one line per Log");
            test.verifyTrue(all(startsWith(test.Captured.Lines, ...
                "[mcp:warning] prodserver:mcp:LogSeverityUnavailable")));
            test.verifySubstring(test.Captured.Lines(1), "`loud`");
        end

        function noInstanceRootUsesInformationQuietly(test)
            log = prodserver.mcp.logging.Log(instanceRoot="", archive="", sink=test.Captured.sink());
            test.verifyEqual(log.level(), prodserver.mcp.logging.Level.Information);
            test.verifyEmpty(test.Captured.Lines, "off MPS there is nothing to report");
        end

        function unreadableMainConfigLogsOnce(test)
            root = string(test.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            prodserver.mcp.logging.Log(instanceRoot=root, archive="", sink=test.Captured.sink());
            test.verifyNumElements(test.Captured.Lines, 1);
            test.verifySubstring(test.Captured.Lines, "LogSeverityUnavailable");
        end

        function beginRequestClearsTheContext(test)
            log = make(test, "");
            log.beginRequest(struct("id", 1));
            log.setContext(tool="t", trace=valid(test));
            log.beginRequest();
            log.log("Information", test.Event, "m");
            test.verifyEqual(test.Captured.Lines, "[mcp:information] " + test.Event + " m");
        end

        function beginRequestDoesNotReadMetaTraceparent(test)
            log = make(test, "");
            jrpc = struct("id", 1, "params", struct("x_meta", struct("traceparent", test.TP)));
            log.beginRequest(jrpc);
            log.log("Information", test.Event, "m");
            test.verifyFalse(contains(test.Captured.Lines, "trace="));
        end

        function setContextTraceSetsLaterLines(test)
            log = make(test, "");
            log.setContext(trace=valid(test));
            log.log("Information", test.Event, "a");
            log.log("Information", test.Event, "b");
            test.verifyTrue(all(contains(test.Captured.Lines, "trace=" + test.TP)));
        end

        function traceHandleIsEvaluatedOnlyWhenALineIsWritten(test)
            log = make(test, "");
            setappdata(0, "tLogCalls", 0);
            test.addTeardown(@() rmappdata(0, "tLogCalls"));
            log.setContext(trace=@() countedTrace(test.TP));
            log.log("Trace", test.Event, "below the threshold");
            test.verifyEqual(getappdata(0, "tLogCalls"), 0, "nothing written, nothing called");
            log.log("Information", test.Event, "a");
            log.log("Information", test.Event, "b");
            test.verifyEqual(getappdata(0, "tLogCalls"), 1);
            test.verifyTrue(all(contains(test.Captured.Lines, "trace=" + test.TP)));
        end

        function traceHandleThatRaisesLeavesTheFieldOut(test)
            log = make(test, "");
            log.setContext(trace=@() error("x:y", "no"));
            log.log("Information", test.Event, "m");
            test.verifyEqual(test.Captured.Lines, "[mcp:information] " + test.Event + " m");
        end

        function invalidTraceContextLeavesTheFieldOut(test)
            log = make(test, "");
            log.setContext(trace=prodserver.mcp.internal.TraceContext());
            log.log("Information", test.Event, "a");
            log.setContext(trace=@() prodserver.mcp.internal.TraceContext("zz"));
            log.log("Information", test.Event, "b");
            test.verifyFalse(any(contains(test.Captured.Lines, "trace=")));
        end

        function toolAndTraceAreIndependent(test)
            log = make(test, "");
            log.setContext(trace=valid(test));
            log.setContext(tool="t2");
            log.log("Information", test.Event, "m");
            test.verifySubstring(test.Captured.Lines, "trace=" + test.TP);
            test.verifySubstring(test.Captured.Lines, "tool=t2");
        end

        function idIsBoundedAndEscaped(test)
            log = make(test, "");
            log.beginRequest(struct("id", "a b" + newline + string(repmat('c', 1, 1000))));
            log.log("Information", test.Event, "m");
            token = extractBetween(test.Captured.Lines, "id=", " m");
            test.verifyFalse(contains(token, [" ", newline]), "one token");
            test.verifySubstring(token, "…(1004)");
            test.verifyLessThan(strlength(token), 160);
        end

        function logNeverRaisesOnAnyInput(test)
            log = make(test, "");
            calls = {@() log.log("Loud", test.Event, "m"), ...
                @() log.log("Warning", 42, "%d %s", struct("a", 1)), ...
                @() log.log("Warning", test.Event, "%s %s %s"), ...
                @() log.logOnce(struct(), "Warning", test.Event, "m"), ...
                @() log.logOncePer(struct(), 1, "Warning", test.Event, "m"), ...
                @() log.logOncePer("k", "soon", "Warning", test.Event, "m"), ...
                @() log.beginRequest(42), ...
                @() log.beginRequest(struct("id", {1, 2})), ...
                @() log.setContext("tool"), ...
                @() log.setContext(tool=struct(), trace=42, color="red"), ...
                @() prodserver.mcp.logging.Log.instance(action="nonsense")};
            for k = 1:numel(calls)
                test.verifyWarningFree(calls{k}, "call " + k);
            end
        end

        function beginRequestAndSetContextDoNoIO(test)
            % After the Log is made, its main_config can go away: no later
            % call reads it, so nothing reports it missing.
            root = instanceWith(test, "--log-severity information");
            log = prodserver.mcp.logging.Log(instanceRoot=root, archive="", sink=test.Captured.sink());
            delete(fullfile(root, "config", "main_config"));
            log.beginRequest(struct("id", 1));
            log.setContext(tool="t", trace=@() valid(test));
            log.log("Information", test.Event, "m");
            test.verifyNumElements(test.Captured.Lines, 1);
            test.verifyFalse(contains(test.Captured.Lines, "LogSeverityUnavailable"));
        end

        function logOnceLogsTheFirstTimeOnly(test)
            log = make(test, "");
            for k = 1:3
                log.logOnce("a_1|X", "Warning", test.Event, "m");
            end
            test.verifyNumElements(test.Captured.Lines, 1);
        end

        function logOncePerLogsAgainAfterTheInterval(test)
            log = make(test, "");
            log.logOncePer("k", 1, "Warning", test.Event, "m %d", 1);
            log.logOncePer("k", 1, "Warning", test.Event, "m %d", 2);
            pause(1.1);
            log.logOncePer("k", 1, "Warning", test.Event, "m %d", 3);
            test.verifyEqual(extractAfter(test.Captured.Lines, "m "), ["1"; "3"]);
        end

        function formatArgumentsAreNeverAnInterval(test)
            % Caller text that reads "interval", 0 is a message argument,
            % not a throttle: the second call is still suppressed.
            log = make(test, "");
            for k = 1:2
                log.logOnce("k", "Warning", test.Event, "%s %d", "interval", 0);
            end
            test.verifyEqual(test.Captured.Lines, "[mcp:warning] " + test.Event + " interval 0");
        end

        function aBadIntervalLogsOnce(test)
            log = make(test, "");
            bad = {"soon", NaN, -1, [1 2]};
            for k = 1:numel(bad)
                for call = 1:2
                    log.logOncePer("k" + k, bad{k}, "Warning", test.Event, "m");
                end
            end
            test.verifyNumElements(test.Captured.Lines, numel(bad), "one line per key");
        end

        function anIdThatIsNotTextStillWritesOneLine(test)
            log = make(test, "");
            log.log("Warning", struct("a", 1), "m");
            test.verifyEqual(test.Captured.Lines, ...
                "[mcp:warning] a\u00201×1\u0020struct\u0020array m");
        end

        function anIdIsOneBoundedToken(test)
            log = make(test, "");
            log.log("Warning", "not an id " + string(repmat('x', 1, 300)), "m");
            test.verifyNumElements(test.Captured.Lines, 1);
            parts = split(test.Captured.Lines, " ");
            test.verifyNumElements(parts, 3, "level, id and message");
            test.verifySubstring(parts(2), "…(310)");
            test.verifyLessThan(strlength(parts(2)), 160);
        end

        function sinkCapturesEveryLine(test)
            log = make(test, "");
            log.Threshold = "Trace";
            log.log("Trace", test.Event, "1");
            log.log("Error", test.Event, "2");
            test.verifyNumElements(test.Captured.Lines, 2);
            test.verifyEqual(test.Captured.Streams', [1 2]);
        end

        function anyFeatureIdentifierIsAccepted(test)
            log = make(test, "");
            log.log("Information", "prodserver:mcp:TracingEnabled", "m");
            test.verifySubstring(test.Captured.Lines, "prodserver:mcp:TracingEnabled");
        end

        function eachArchiveCopyHasItsOwnLog(test)
            % FA-10: instance() keeps the Log in archiveCache, so each
            % archive copy, whose archiveCache is its own, has its own Log,
            % which names its own archive from deployedArchiveLocation.
            import prodserver.mcp.logging.Log
            deployed = test.applyFixture(prodserver.mcp.test.mixin.DeployedArchiveFixture("a_1"));
            a = Log.instance();
            test.verifySameHandle(Log.instance(), a, "one Log per archive copy");
            deployed.deployAs("b_2");
            b = Log.instance();
            test.verifyNotSameHandle(b, a);
            a.Sink = test.Captured.sink();
            b.Sink = test.Captured.sink();
            a.log("Information", test.Event, "m");
            b.log("Information", test.Event, "m");
            test.verifySubstring(test.Captured.Lines(1), " archive=a_1 ");
            test.verifySubstring(test.Captured.Lines(2), " archive=b_2 ");
        end
    end

    methods (Access = private)
        function log = make(test, archive)
            log = prodserver.mcp.logging.Log(instanceRoot="", archive=archive, sink=test.Captured.sink());
        end

        function tc = valid(test)
            tc = prodserver.mcp.internal.TraceContext(test.TP);
        end

        function root = instanceWith(test, lines)
            root = string(test.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            mkdir(fullfile(root, "config"));
            fid = fopen(fullfile(root, "config", "main_config"), "w");
            fprintf(fid, "%s\n", lines);
            fclose(fid);
        end
    end
end

function tc = countedTrace(tp)
    setappdata(0, "tLogCalls", getappdata(0, "tLogCalls") + 1);
    tc = prodserver.mcp.internal.TraceContext(tp);
end
