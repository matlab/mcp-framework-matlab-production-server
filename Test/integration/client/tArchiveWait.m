classdef tArchiveWait < MockCaller
% How list, call, read and exist wait for an archive that answers 404, and
% how they recover when an endpoint's protocol revision has changed.
%
% MATLAB Production Server answers 404, with no body, alike for an archive
% it doesn't have and for one it is still deploying. So the client polls a
% 404 for as long as its retry and delay allow, and then raises
% UnknownArchive. It used to raise HttpError, which isProtocolError takes
% for a stale cached revision: the function then forgot the revision,
% probed again and waited all over again, so a missing archive took two
% waits (51 seconds for list, 130 for call). The recovery is for an
% archive redeployed with another revision, which the archive itself
% refuses; the tests here pin that it still works.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        Endpoint
    end

    properties (TestParameter)
        % A missing archive, through each function that opens a client.
        % retry=2 and a short delay keep the wait short.
        missingVia = struct( ...
            "list", @(ep) prodserver.mcp.list(ep, "Tool", retry=2, delay=0.1), ...
            "read", @(ep) prodserver.mcp.read(ep, "mcp://x/y", retry=2, delay=0.1), ...
            "exist", @(ep) prodserver.mcp.exist(ep, "f", "Tool", retry=2, delay=0.1))
    end

    methods (TestMethodSetup)
        function startServer(test)
            config = fullfile(fileparts(mfilename("fullpath")), ...
                "tArchiveWait.yaml");
            test.Endpoint = test.startMcpServer(config);
            prodserver.mcp.client.Adapter.create(action="clearAll");
            test.addTeardown(@() prodserver.mcp.client.Adapter.create( ...
                action="clearAll"));
        end
    end

    methods (Static, Hidden)

        function err = listOrError(ep)
        % list(EP)'s error, so evalc can complete and keep what it showed.
            err = [];
            try
                prodserver.mcp.list(ep, "Tool", retry=2, delay=0.1);
            catch err
            end
        end

    end

    methods (Access = private)

        function ep = at(test, archive)
            ep = replace(test.Endpoint, "/mcp", "/" + archive + "/mcp");
        end

        function n = posts(test, archive)
            n = test.requestCount("POST", "/" + archive + "/mcp");
        end

        function [warnings, err] = listCapturingWarnings(test, ep)
        % The warnings list(EP) shows, as the user sees them -- each a line
        % beginning "Warning: " -- and the error it ends with.
            warning("on", "prodserver:mcp:WaitingForArchive");
            output = string(evalc("err = tArchiveWait.listOrError(ep);"));
            test.assertNotEmpty(err, "Expected an error.");
            % The display wraps a long warning onto several lines, and
            % ends it with a blank one.
            warnings = string(regexp(output, ...
                "Warning: .*?(?=\n\s*\n|$)", "match"));
            warnings = regexprep(warnings, "\s*\n\s*", " ");
        end

    end

    methods (Test)

        function missingArchiveIsOneWait(test, missingVia)
            % The probe meets the 404 first, waits it out, and stops: no
            % initialize, and no second probe.
            ep = test.at("gone");
            try
                missingVia(ep);
                test.verifyFail("Expected UnknownArchive.");
            catch me
                test.verifyEqual(string(me.identifier), ...
                    "prodserver:mcp:UnknownArchive");
                test.verifySubstring(me.message, ep);
                test.verifySubstring(me.message, "can't be told apart");
                test.verifySubstring(me.message, "try again");
            end
            test.verifyEqual(test.posts("gone"), 3, ...
                "One wait of 1 + retry requests.");
        end

        function callWaitsOnceForAMissingArchive(test)
            % call has no options: it waits Constants.ArchiveRetry retries,
            % about a minute, once.
            ep = test.at("gone");
            test.verifyError(@() prodserver.mcp.call(ep, "f", 1), ...
                "prodserver:mcp:UnknownArchive");
            test.verifyEqual(test.posts("gone"), ...
                1 + prodserver.mcp.internal.Constants.ArchiveRetry);
        end

        function cachedRevisionStillOneWait(test)
            % With the revision cached there's no probe: the request itself
            % waits, and that is all.
            ep = test.at("gone");
            prodserver.mcp.client.Adapter.create(ep, protocol="2026-07-28");
            test.verifyError(@() prodserver.mcp.list(ep, "Tool", ...
                retry=2, delay=0.1), "prodserver:mcp:UnknownArchive");
            test.verifyEqual(test.posts("gone"), 3, ...
                "No second round, and so no probe.");
        end

        function revisionChangeRecovers(test)
            % What the recovery is for: cached as 2026-07-28, redeployed
            % with an archive that speaks only 2025-06-18, which refuses the
            % old revision. list forgets it, probes, and succeeds.
            ep = test.at("moved");
            prodserver.mcp.client.Adapter.create(ep, protocol="2026-07-28");
            tools = prodserver.mcp.list(ep, "Tool", retry=2, delay=0.1);
            test.verifyEqual(string(tools{1}.name), "addNumbers");
            % tools/list refused, server/discover, initialize, initialized,
            % tools/list.
            test.verifyEqual(test.posts("moved"), 5);
        end

        function revisionChangeBehind404sRecovers(test)
            % The same, caught mid-redeploy: three 404s, then the refusal.
            % The wait covers the 404s, and the recovery the refusal.
            ep = test.at("late");
            prodserver.mcp.client.Adapter.create(ep, protocol="2026-07-28");
            tools = prodserver.mcp.list(ep, "Tool", retry=5, delay=0.1);
            test.verifyEqual(string(tools{1}.name), "addNumbers");
            test.verifyEqual(test.posts("late"), 8);
        end

        function waitingIsExplained(test)
            % One warning, at the first 404, saying why the wait is coming
            % and how to stop it, with the server's nearest name.
            ep = test.at("primeSeqence");
            [warnings, err] = test.listCapturingWarnings(ep);
            test.verifyEqual(err.identifier, 'prodserver:mcp:UnknownArchive');
            test.assertNumElements(warnings, 1, "Warned once.");
            test.verifySubstring(warnings, "No archive answers at " + ep);
            test.verifySubstring(warnings, "Ctrl+C");
            test.verifySubstring(warnings, ...
                "an archive with a similar name: 'primeSequence'");
            test.verifySubstring(err.message, "'primeSequence'", ...
                "The error repeats the hint.");
        end

        function listedButNotAnsweringIsStarting(test)
            [warnings, err] = test.listCapturingWarnings(test.at("loading"));
            test.assertNumElements(warnings, 1);
            test.verifySubstring(warnings, "probably still starting");
            test.verifySubstring(err.message, "probably still starting");
        end

        function hintUsesArchiveNamesNotFieldNames(test)
            [warnings, ~] = test.listCapturingWarnings(test.at("my-tol"));
            test.assertNumElements(warnings, 1);
            test.verifySubstring(warnings, "'my-tool'");
        end

        function hintUsesDeployedNamesNotBuildNames(test)
            % An archive file renamed before it was deployed keeps its
            % build's name in its UUID. The hint names the deployed one,
            % once, and the build's name only where it is an archive's.
            [warnings, ~] = test.listCapturingWarnings(test.at("renamedCopi"));
            test.assertNumElements(warnings, 1);
            test.verifySubstring(warnings, ...
                "an archive with a similar name: 'renamedCopy'");
        end

        function noHintForADistantName(test)
            [warnings, err] = test.listCapturingWarnings(test.at("zzzzzz"));
            test.assertNumElements(warnings, 1);
            test.verifyFalse(contains(warnings, "similar"));
            test.verifyFalse(contains(err.message, "similar"));
        end

        function metricsWaitsForAMissingArchive(test)
            % metrics checks the archive at its /ping route, which counts
            % nothing, and waits out the 404 as the others do. It used to
            % raise UnknownArchive at once: wrong while one is deploying.
            ep = test.at("gone");
            test.verifyError(@() prodserver.mcp.metrics(ep, retry=2, ...
                delay=0.1), "prodserver:mcp:UnknownArchive");
            test.verifyEqual(test.requestCount("GET", "/gone/ping"), 3, ...
                "One wait of 1 + retry requests.");
        end

        function metricsReadsAPresentArchive(test)
            c = prodserver.mcp.metrics(test.at("present"));
            test.verifyNumElements(c.scope(prodserver.mcp.metrics.Scope.All), 1);
            test.verifyEqual(test.requestCount("GET", "/present/ping"), 1);
        end

        function metricsOnAStoppedServerIsUnresponsive(test)
            % A refused connection is resent once, as for the others, not
            % RETRY times, and then the server is unresponsive. RETRY times
            % would take over 30 s here: 30 pauses of 1 s.
            for ep = ["http://127.0.0.1:1/x/mcp", "http://127.0.0.1:1"]
                t = tic;
                test.verifyError(@() prodserver.mcp.metrics(ep, retry=30, ...
                    delay=1, timeout=5), ...
                    "prodserver:mcp:ServerUnresponsive", ep);
                test.verifyLessThan(toc(t), 15, ep + ": resent once, not 30 times.");
            end
        end

        function frameworkNotFoundIsNotWaitedOn(test)
            % A 404 with a body came from the archive: it is there, and
            % will say the same again. Sent once, and an HttpError.
            uri = matlab.net.URI(test.at("bodied"));
            body = matlab.net.http.MessageBody(struct('jsonrpc', "2.0", ...
                'id', 1, 'method', "tools/list"));
            request = matlab.net.http.RequestMessage('POST', ...
                matlab.net.http.field.ContentTypeField('application/json'), body);
            test.verifyError(@() prodserver.mcp.internal.sendRequest( ...
                request, uri, delay=0.1), "prodserver:mcp:HttpError");
            test.verifyEqual(test.posts("bodied"), 1);
        end

    end
end
