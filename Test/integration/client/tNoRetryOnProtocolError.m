classdef tNoRetryOnProtocolError < MockCaller
% A 4xx carrying a JSON-RPC error body is a deterministic rejection -- an
% unsupported protocol version, a header mismatch, a malformed request. The
% server will answer identically every time, so sendRequest must stop
% immediately instead of exhausting its retry budget, and requireSuccess must
% surface the server's structured message rather than the bare status line.
%
% Before the retry-loop break, a 400 sat squarely inside the 4xx retry
% window: the client sent the same doomed request four times with a two-second
% pause between attempts, then reported only "failed with error code 400".
%
% These tests drive prodserver.mcp.internal.sendRequest directly rather than
% going through prodserver.mcp.list. That is deliberate: the higher-level
% entry points probe more than one protocol version and, because
% isProtocolError now treats RemoteError as a possible stale-cache signal,
% clear the adapter cache and probe again. The resulting request count is a
% property of protocol negotiation, not of the retry loop, so it cannot
% distinguish the behavior under test.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        % sendRequest defaults to retry=3, so a retryable status (404, 408,
        % 429) arrives 1 + 3 = 4 times.
        RetriedAttempts = 4;
    end

    methods (Access = private)

        function req = toolsListRequest(~)
            import matlab.net.http.*
            body = MessageBody(struct('jsonrpc', "2.0", 'id', 1, ...
                'method', "tools/list"));
            req = RequestMessage('POST', ...
                field.ContentTypeField('application/json'), body);
        end

    end

    methods (Test)

        function jsonRpcErrorBodyIsNotRetried(test)
            endpoint = startMcpServer(test,"tNoRetryOnProtocolError.yaml");
            uri = matlab.net.URI(endpoint);

            before = test.requestCount("POST","/mcp");

            try
                prodserver.mcp.internal.sendRequest( ...
                    test.toolsListRequest(), uri, delay=0.1);
                test.verifyFail("Expected the 400 to surface as an error.");
            catch err
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:RemoteError", ...
                    "A JSON-RPC error body must not flatten to HttpError");
                test.verifyTrue(contains(err.message, ...
                    "Unsupported protocol version"), ...
                    "The server's message must survive: " + err.message);
                test.verifyTrue(contains(err.message,"-32022"), ...
                    "The JSON-RPC code must be reported: " + err.message);
            end

            attempts = test.requestCount("POST","/mcp") - before;
            test.verifyEqual(attempts, 1, ...
                "A deterministic 400 must be sent exactly once; saw " + ...
                attempts);
        end

        function opaqueClientErrorIsNotRetried(test)
            % A 400 is a verdict on the request whether or not it carries a
            % JSON-RPC error body, so it is sent once either way. This test
            % used to assert the opposite -- that an opaque 400 was retried
            % -- because sendRequest retried every 4xx; that window is now
            % the allow-list Constants.RetryableStatus (XD14).
            endpoint = startMcpServer(test,"tNoRetryOnProtocolError.yaml");
            uri = matlab.net.URI(replace(endpoint,"/mcp","/opaque"));

            test.verifyError(@() prodserver.mcp.internal.sendRequest( ...
                test.toolsListRequest(), uri, delay=0.1), ...
                "prodserver:mcp:HttpError", ...
                "A bare 400 has no JSON-RPC error to report");

            attempts = test.requestCount("POST","/opaque");
            test.verifyEqual(attempts, 1, ...
                "An opaque 400 must be sent exactly once; saw " + attempts);
        end

        function throttledRequestIsRetried(test)
            % The negative control: 429 can change while the request does
            % not, so it still uses the whole retry budget.
            endpoint = startMcpServer(test,"tNoRetryOnProtocolError.yaml");
            uri = matlab.net.URI(replace(endpoint,"/mcp","/throttled"));

            test.verifyError(@() prodserver.mcp.internal.sendRequest( ...
                test.toolsListRequest(), uri, delay=0.1), ...
                "prodserver:mcp:HttpError");

            attempts = test.requestCount("POST","/throttled");
            test.verifyEqual(attempts, test.RetriedAttempts, ...
                "A 429 must be retried; saw " + attempts);
        end

        function missingArchiveIsRetried(test)
            % 404 is Production Server's answer while an archive is still
            % being unpacked. The mock answers an unrouted path with 404 and
            % a JSON body that is not a JSON-RPC error, as close as it gets
            % to Production Server's empty-bodied 404.
            endpoint = startMcpServer(test,"tNoRetryOnProtocolError.yaml");
            uri = matlab.net.URI(replace(endpoint,"/mcp","/absent"));

            test.verifyError(@() prodserver.mcp.internal.sendRequest( ...
                test.toolsListRequest(), uri, delay=0.1), ?MException);

            attempts = test.requestCount("POST","/absent");
            test.verifyEqual(attempts, test.RetriedAttempts, ...
                "A 404 must be retried; saw " + attempts);
        end

        function noPauseAfterLastAttempt(test)
            % retry=1 is two attempts and one pause. The loop used to pause
            % after the final attempt too, adding a full delay to every
            % exhausted retry for nothing (ND11). Request latency to the mock
            % varies far more than a test can tolerate in absolute terms, so
            % time the same two attempts with and without a long delay: the
            % difference is the pausing alone.
            endpoint = startMcpServer(test,"tNoRetryOnProtocolError.yaml");
            uri = matlab.net.URI(replace(endpoint,"/mcp","/throttled"));
            delay = 3;
            exhaust = @(d) prodserver.mcp.internal.sendRequest( ...
                test.toolsListRequest(), uri, retry=1, delay=d);

            % Warm up matlab.net.http; its first request is slow.
            test.verifyError(@() exhaust(0.01), "prodserver:mcp:HttpError");

            t = tic;
            test.verifyError(@() exhaust(0.01), "prodserver:mcp:HttpError");
            baseline = toc(t);

            t = tic;
            test.verifyError(@() exhaust(delay), "prodserver:mcp:HttpError");
            paused = toc(t) - baseline;

            test.verifyEqual(test.requestCount("POST","/throttled"), 6);
            test.verifyGreaterThan(paused, 0.5*delay, ...
                "Did not pause between attempts: " + paused + " s");
            test.verifyLessThan(paused, 1.5*delay, ...
                "Paused after the last attempt: " + paused + " s");
        end

    end

end
