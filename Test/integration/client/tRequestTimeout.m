classdef tRequestTimeout < MockCaller
% A server slow to answer, as one is while a worker loads an archive after a
% restart (when /api/health already says ok).
%
% The first prodserver.mcp.call after a restart used to fail at once: its
% tools/list had a 10 second timeout, and sendRequest retried only HTTP
% statuses, so a timeout ended it on the first attempt with
% matlab.net.http's own error. Now a request that changes nothing is sent
% again, once, when it gets no answer; a tools/call never is, since it may
% have run. Either way, a request that still gets no answer raises
% prodserver:mcp:RequestTimeout, which says the server may be starting.
%
% Short timeouts, so the tests are quick: 2 s, against answers that take
% 6 s, from a threaded mock server (see tRequestTimeout.yaml).

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function clearProtocolCache(~)
            prodserver.mcp.client.Adapter.create(action="clearAll");
        end
    end

    methods (Test)

        function slowListIsRetried(test)
            client = test.adapter("/slowlist/mcp");
            items = client.list("Tool", timeout=2, retry=3, delay=0.1);
            test.verifyEqual(string(items.tools{1}.name), "f1");
            test.verifyEqual(test.requestCount("POST", "/slowlist/mcp"), 2, ...
                "Sent again once, after the first got no answer.");
        end

        function listThatNeverAnswersRaisesFrameworkError(test)
            % One resend, however many status retries the caller allows:
            % retry is for quick statuses, and 30 of them is a caller's
            % real choice (the 2025-06-18 initialize). Counted as one, a
            % server that never answers held a call for 31 timeouts.
            client = test.adapter("/neverlist/mcp");
            t = tic;
            err = captureError(@() client.list("Tool", timeout=2, ...
                retry=30, delay=0.1), 0);
            elapsed = toc(t);
            test.assertNotEmpty(err, "Expected RequestTimeout.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:RequestTimeout", err.message);
            test.verifySubstring(err.message, "tools/list");
            test.verifySubstring(err.message, "2 attempt(s)");
            test.verifySubstring(err.message, "first request to an archive");
            test.verifyEqual(test.requestCount("POST", "/neverlist/mcp"), 2);
            test.verifyLessThan(elapsed, 20, ...
                "Two timeouts, not thirty-one.");
        end

        function metricsTimeoutIsUnresponsive(test)
            % /api/metrics isn't resent after a timeout, and the error is
            % the framework's, not matlab.net's, which shows the address
            % as given.
            server = extractBefore(test.endpoint("/discover/mcp"), "/discover/mcp");
            server = replace(server, "://", "://alice:s3cr3tSENTINEL@");
            err = captureError(@() prodserver.mcp.metrics(server, ...
                timeout=2, delay=0.1), 0);
            test.assertNotEmpty(err, "Expected ServerUnresponsive.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:ServerUnresponsive", err.message);
            test.verifySubstring(err.message, "2 second timeout");
            test.verifyFalse(contains(err.message, "s3cr3tSENTINEL"), err.message);
            test.verifyFalse(contains(err.message, "alice"), err.message);
            test.verifyEqual(test.requestCount("GET", "/api/metrics"), 1);
        end

        function stoppedServerFailsQuickly(test)
            % A refused connection is resent once too, not retry times.
            endpoint = test.endpoint("/neverlist/mcp");
            test.stopMcpServer();
            client = prodserver.mcp.client.v20260728.Adapter(endpoint);
            t = tic;
            err = captureError(@() client.list("Tool", timeout=2, ...
                retry=30, delay=0.1), 0);
            elapsed = toc(t);
            test.assertNotEmpty(err, "A stopped server must raise.");
            % A transport failure, whichever the stopping server gives:
            % refused, reset while it shuts down, or on Windows, where a
            % refusal takes about 2 s, the 2 s timeout first. Not another
            % kind of error, such as one of the framework's own.
            id = string(err.identifier);
            test.verifyTrue(id == "prodserver:mcp:RequestTimeout" || ...
                startsWith(id, "MATLAB:webservices:"), id + ": " + err.message);
            % A refusal takes about 2 s on Windows: two attempts take 4,
            % thirty-one would take a minute.
            test.verifyLessThan(elapsed, 10, ...
                "Two attempts, not thirty-one: " + err.message);
        end

        function slowCallIsNotRepeated(test)
            % It may have run: sent once, and the error says to check.
            client = test.adapter("/slowcall/mcp");
            data = struct('jsonrpc', "2.0", 'method', "tools/call", ...
                'params', struct('name', "f1", 'arguments', struct('x', 3)));
            err = captureError(@() client.send(data, timeout=2, ...
                retry=3, delay=0.1), 0);
            test.assertNotEmpty(err, "Expected RequestTimeout.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:RequestTimeout", err.message);
            test.verifySubstring(err.message, "may still have acted on it");
            test.verifyEqual(test.requestCount("POST", "/slowcall/mcp"), 1, ...
                "A tools/call must not be sent again.");
        end

        function unansweredProbeIsNotCached(test)
            % With no answer, the client falls back to 2025-06-18 for this
            % call, but asks again next time rather than keeping the guess.
            endpoint = test.endpoint("/slowdiscover/mcp");
            create = @() prodserver.mcp.client.Adapter.create(endpoint, ...
                timeout=2, retry=1, delay=0.1);
            client = create();
            test.verifyEqual(client.Version, ...
                prodserver.mcp.client.v20250618.Adapter.Version);
            test.verifyEqual(test.requestCount("POST", "/slowdiscover/mcp"), 2, ...
                "The probe, and its one resend.");
            create();
            test.verifyEqual(test.requestCount("POST", "/slowdiscover/mcp"), 4, ...
                "The second create asks again.");
        end

        function answeredProbeIsCached(test)
            endpoint = test.endpoint("/discover/mcp");
            client = prodserver.mcp.client.Adapter.create(endpoint);
            test.verifyEqual(client.Version, ...
                prodserver.mcp.client.v20260728.Adapter.Version);
            prodserver.mcp.client.Adapter.create(endpoint);
            test.verifyEqual(test.requestCount("POST", "/discover/mcp"), 1, ...
                "The answer is kept.");
        end

    end

    methods (Access = private)

        function endpoint = endpoint(test, path)
        % The mock's address, http://127.0.0.1:<port>/mcp, with PATH for
        % its path.
            server = test.startMcpServer("tRequestTimeout.yaml", threaded=true);
            endpoint = extractBefore(server, "/mcp" + textBoundary("end")) + path;
        end

        function client = adapter(test, path)
        % A 2026-07-28 client, made directly: no probe to count.
            client = prodserver.mcp.client.v20260728.Adapter(test.endpoint(path));
        end

    end

end
