classdef tDeployTransport < MockCaller
% Deploy and client transport, against a mock MATLAB Production Server
% (conformance Phase XC).
%
% Request counts come from the mock's /stats. They are the only external
% evidence of whether something was retried, and retrying the wrong thing --
% or not retrying the right one -- is most of what this phase fixed.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Config = "tDeployTransport.yaml"
        % Every slow route sleeps 5 s, and a request bounded at 2 s must raise
        % a response timeout. Without the bound, each of those requests would
        % wait and then succeed, so the error identifier is the evidence.
        % Elapsed time is not: connecting to the mock on localhost costs up
        % to ~2 s on top of the timeout, which says nothing about the code.
        Timeout = 2
        TimedOut = "MATLAB:webservices:Timeout"
    end

    properties
        url
        folder
    end

    methods (TestMethodSetup)

        function start(test)
            endpoint = startMcpServer(test, test.Config);
            test.url = string(extractBefore(endpoint, "/mcp"));
            test.folder = string(test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
        end

    end

    methods (Access = private)

        function ctf = archive(test, outcome)
        % A fake archive whose contents choose the mock's upload answer.
            ctf = fullfile(test.folder, outcome + ".ctf");
            fid = fopen(ctf, "w");
            fwrite(fid, outcome);
            fclose(fid);
        end

        function ctf = build(test, name)
        % A fake archive with a manifest, as mcc writes one: a zip file
        % whose .META/manifest.xml names build "<name>_new". The mock
        % accepts any such upload.
            root = fullfile(test.folder, name);
            mkdir(fullfile(root, ".META"));
            writelines("<manifest container_uuid="""" uuid=""" + name + ...
                "_new""></manifest>", fullfile(root, ".META", "manifest.xml"));
            zip(fullfile(test.folder, name + ".zip"), ".META", root);
            ctf = fullfile(test.folder, name + ".ctf");
            movefile(fullfile(test.folder, name + ".zip"), ctf);
        end

        function endpoint = deploy(test, outcome, verify)
            arguments
                test
                outcome string
                verify double = 5
            end
            endpoint = prodserver.mcp.deploy(test.archive(outcome), ...
                test.url, retry=3, delay=0.1, timeout=5, verify=verify);
        end

    end

    methods (Test)

        % XD24: the upload's status decides deploy's error.

        function uploadRejectionIsNotRetried(test)
            try
                test.deploy("reject", 0);
                test.verifyFail("A 403 upload must raise.");
            catch err
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:ArchiveUploadRejected");
                test.verifyTrue(contains(err.message, ...
                    "Archive name not allowed"), ...
                    "The server's reason must survive: " + err.message);
            end
            test.verifyEqual(test.requestCount("POST", "/api/archives"), 1, ...
                "A 4xx is the server's settled answer; send it once");
        end

        function uploadServerFailureIsRetriedThenReported(test)
            try
                test.deploy("fail", 0);
                test.verifyFail("A 500 upload must raise.");
            catch err
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:ArchiveUploadFailed");
                test.verifyTrue(contains(err.message, ...
                    "Archive Create Error"), err.message);
            end
            test.verifyEqual(test.requestCount("POST", "/api/archives"), 3, ...
                "A 5xx may be transient; use the whole retry budget");
        end

        function acceptedUploadIsVerifiedByPing(test)
            endpoint = test.deploy("accept");
            test.verifyEqual(string(endpoint), test.url + "/accept/mcp");
            test.verifyEqual(test.requestCount("POST", "/api/archives"), 1);
            test.verifyEqual(test.requestCount("GET", "/accept/ping"), 1);
        end

        function deployWithoutVerifyReturnsEndpoint(test)
            % The endpoint prefix used to be assigned only inside the verify
            % block.
            endpoint = test.deploy("accept", 0);
            test.verifyEqual(string(endpoint), test.url + "/accept/mcp");
            test.verifyEqual(test.requestCount("GET", "/accept/ping"), 0);
        end

        % An update takes effect seconds after the upload returns, and until
        % then the archive replaced answers ping. deploy waits for the build
        % it uploaded.

        function updateWaitsForTheBuildUploaded(test)
            endpoint = prodserver.mcp.deploy(test.build("fresh"), test.url, ...
                retry=5, delay=0.1, timeout=5);
            test.verifyEqual(string(endpoint), test.url + "/fresh/mcp");
            test.verifyEqual(test.requestCount("GET", "/fresh/ping"), 4, ...
                "Two answers from the old build, then two from the new");
            test.verifyEqual(test.requestCount("GET", "/api/discovery"), 0, ...
                "An archive that names its build needs no discovery");
        end

        function updateThatNeverTakesEffectIsStale(test)
            try
                prodserver.mcp.deploy(test.build("stale"), test.url, ...
                    retry=3, verify=1, delay=0.1, timeout=5);
                test.verifyFail("An archive that never changes over must raise.");
            catch err
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:DeployedArchiveStale");
                test.verifySubstring(err.message, "stale_old");
                test.verifySubstring(err.message, "stale_new");
            end
            test.verifyEqual(test.requestCount("GET", "/stale/ping"), 3);
        end

        function buildWithoutHeaderIsToldByDiscovery(test)
            % Built before ping named its build: discovery says which build
            % is live, and is old for the first ping.
            prodserver.mcp.deploy(test.build("nohdr"), test.url, ...
                retry=5, delay=0.1, timeout=5);
            test.verifyEqual(test.requestCount("GET", "/nohdr/ping"), 3);
            test.verifyEqual(test.requestCount("GET", "/api/discovery"), 3);
        end

        function slowDiscoveryIsNotWaitedFor(test)
            % Discovery is given Constants.DiscoveryTimeout (10 s), not the
            % whole timeout. This one answers after 12 s -- that the old
            % build is live -- so deploy gives up on it and takes the pong.
            % Waiting the whole timeout, it would hear "old" and raise
            % DeployedArchiveStale instead.
            endpoint = startMcpServer(test, "tDeployDiscovery.yaml");
            test.url = string(extractBefore(endpoint, "/mcp"));
            prodserver.mcp.deploy(test.build("slowdisc"), test.url, ...
                retry=2, verify=1, delay=0.1, timeout=60);
            test.verifyEqual(test.requestCount("GET", "/slowdisc/ping"), 1);
            test.verifyEqual(test.requestCount("GET", "/api/discovery"), 1);
        end

        function buildWithoutHeaderOrDiscoveryAcceptsPong(test)
            % Nothing tells the builds apart, so a pong is the answer, as it
            % always was.
            prodserver.mcp.deploy(test.build("legacy"), test.url, ...
                retry=5, delay=0.1, timeout=5);
            test.verifyEqual(test.requestCount("GET", "/legacy/ping"), 1);
        end

        % A 500 says why in its status line's reason phrase -- all that
        % webread's error message, which deploy used to read, contains.

        function endOfFileIsRetried(test)
            % The archive is still being loaded.
            prodserver.mcp.deploy(test.archive("eof"), test.url, ...
                retry=5, delay=0.1, timeout=5);
            test.verifyEqual(test.requestCount("GET", "/eof/ping"), 3, ...
                "Two 500s, then the pong");
        end

        function endOfFileInTheBodyIsRetried(test)
            prodserver.mcp.deploy(test.archive("eofbody"), test.url, ...
                retry=5, delay=0.1, timeout=5);
            test.verifyEqual(test.requestCount("GET", "/eofbody/ping"), 2);
        end

        function pipeEndedNeedsMultiMCOS(test)
            test.verifyError(@() prodserver.mcp.deploy(test.archive("pipe"), ...
                test.url, retry=5, delay=0.1, timeout=5), ...
                "prodserver:mcp:NeedMultiMCOSMode");
            test.verifyEqual(test.requestCount("GET", "/pipe/ping"), 1, ...
                "A class clash is not retried");
        end

        % XD28: isserver.

        function isserverStopsAtFirstAnswer(test)
            [tf, active] = prodserver.mcp.validation.isserver(test.url, ...
                retry=5);
            test.verifyTrue(tf);
            test.verifyTrue(active);
            test.verifyEqual(test.requestCount("GET", "/api/health"), 1, ...
                "One healthy answer is enough");
        end

        function isserverWithNoRetryBudgetIsInactive(test)
            % Used to raise "Unrecognized function or variable 'result'".
            [tf, active] = prodserver.mcp.validation.isserver(test.url, ...
                retry=0);
            test.verifyTrue(tf);
            test.verifyFalse(active);
        end

        function isserverRefusedIsInactiveNotAnError(test)
            % A refused connection is retried (the server may be starting),
            % and running out of attempts reports an inactive server. It
            % used to be rethrown, while deploy's own health check retried
            % it -- two policies for one question.
            [tf, active] = prodserver.mcp.validation.isserver( ...
                "http://localhost:1", retry=2, delay=0.1, timeout=5);
            test.verifyTrue(tf);
            test.verifyFalse(active);
        end

        function deployToRefusedServerIsUnresponsive(test)
            ctf = test.archive("accept");
            test.verifyError(@() prodserver.mcp.deploy(ctf, ...
                "http://localhost:1", retry=2, delay=0.1, timeout=5), ...
                "prodserver:mcp:ServerUnresponsive");
        end

        function deployChecksHealthOnce(test)
            % uploadCTF no longer repeats deploy's health check.
            test.deploy("accept", 0);
            test.verifyEqual(test.requestCount("GET", "/api/health"), 1);
        end

        % webreadWithRetry, the loop behind isserver, metrics, ping and the
        % archive listing.

        function webreadRetriesWhatItIsToldTo(test)
            [r, lastError] = prodserver.mcp.internal.webreadWithRetry( ...
                test.url + "/absent/ping", weboptions, attempts=3, ...
                delay=0.1, retryable=@(me) contains(me.identifier, "HTTP404"));
            test.verifyEmpty(r);
            test.verifySubstring(lastError.identifier, "HTTP404");
            test.verifyEqual(test.requestCount("GET", "/absent/ping"), 3);
        end

        function webreadRethrowsWhatItIsNotToldToRetry(test)
            test.verifyError(@() prodserver.mcp.internal.webreadWithRetry( ...
                test.url + "/broken/ping", weboptions, attempts=3, ...
                delay=0.1, retryable=@(me) contains(me.identifier, "HTTP404")), ...
                "MATLAB:webservices:HTTP500StatusCodeError");
            test.verifyEqual(test.requestCount("GET", "/broken/ping"), 1);
        end

        function webreadRetriesAnUnacceptableAnswer(test)
            [r, lastError] = prodserver.mcp.internal.webreadWithRetry( ...
                test.url + "/accept/ping", weboptions, attempts=2, ...
                delay=0.1, accept=@(~) false);
            test.verifyEqual(string(r), "pong");
            test.verifyEmpty(lastError, ...
                "The last attempt read an answer; there is no error to report");
            test.verifyEqual(test.requestCount("GET", "/accept/ping"), 2);
        end

        function webreadWithNoAttemptsSendsNothing(test)
            r = prodserver.mcp.internal.webreadWithRetry( ...
                test.url + "/accept/ping", weboptions, attempts=0);
            test.verifyEmpty(r);
            test.verifyEqual(test.requestCount("GET", "/accept/ping"), 0);
        end

        % ND2: ping.

        function pingAnswers(test)
            test.verifyTrue(prodserver.mcp.ping(test.url + "/accept/mcp", ...
                retry=3, delay=0.1));
            test.verifyEqual(test.requestCount("GET", "/accept/ping"), 1);
        end

        function pingRetriesAnArchiveNotYetThere(test)
            % 404 (still unpacking) is retried. ping used to overwrite its own
            % options, throw on the first retry, and report false at once.
            test.verifyFalse(prodserver.mcp.ping(test.url + "/absent/mcp", ...
                retry=2, delay=0.1));
            test.verifyEqual(test.requestCount("GET", "/absent/ping"), 3, ...
                "1 attempt + 2 retries");
        end

        function pingDoesNotRetryOtherFailures(test)
            test.verifyFalse(prodserver.mcp.ping(test.url + "/broken/mcp", ...
                retry=2, delay=0.1));
            test.verifyEqual(test.requestCount("GET", "/broken/ping"), 1);
        end

        % XD29: response timeouts.

        function signatureIsBounded(test)
            client = prodserver.mcp.client.Adapter.create( ...
                test.url + "/slow/mcp", protocol="2025-06-18");
            test.addTeardown(@() prodserver.mcp.client.Adapter.create( ...
                test.url + "/slow/mcp", action="clear"));
            test.verifyError(@() prodserver.mcp.internal.signature("toy", ...
                test.url + "/slow/signature", client, timeout=test.Timeout), ...
                test.TimedOut);
        end

        function terminateIsBounded(test)
            % terminate runs inside onCleanup, where an unbounded wait would
            % hang the caller after its result was already computed.
            test.verifyError(@() prodserver.mcp.internal.terminate( ...
                test.url + "/slow/mcp", "alpha", timeout=test.Timeout), ...
                test.TimedOut);
        end

        % ND9: a handshake that fails after the session exists ends it.

        function missingCapabilityTerminatesSession(test)
            test.verifyError(@() prodserver.mcp.internal.initialize( ...
                test.url + "/notools/mcp", require="Tool", retry=1, ...
                delay=0.1), "prodserver:mcp:NoToolsOnServer");
            test.verifyEqual(test.requestCount("DELETE", "/notools/mcp"), 1, ...
                "The minted session must be terminated");
        end

        function slowInitializedNotificationIsBoundedAndTerminates(test)
            % initialize rethrows the notification's failure after ending
            % the session. (The mock is single-threaded, so that terminate
            % queues behind the delayed handler.)
            test.verifyError(@() prodserver.mcp.internal.initialize( ...
                test.url + "/slowack/mcp", require="Tool", retry=1, ...
                delay=0.1, timeout=test.Timeout), test.TimedOut);
            test.verifyEqual(test.requestCount("DELETE", "/slowack/mcp"), 1, ...
                "The minted session must be terminated");
        end

    end

end
