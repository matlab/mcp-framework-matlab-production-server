classdef MockCaller < matlab.unittest.TestCase

% Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        % The mock's address, not "localhost": on Windows, localhost tries
        % IPv6 (::1) first, where the mock doesn't listen, and every
        % request then waited about 2 seconds for the fallback to IPv4.
        Host = "127.0.0.1"
    end

    properties
        port = 50101
        server = fullfile(fileparts(mfilename("fullpath")), ...
            "..", "..", "mocks", "server", "mock_server.py");
        python = "python3"
    end

    methods(TestClassSetup)
        function findPython(test)
            pythonFromEnv = getenv("MCP_TEST_PYTHON_PATH");
            if isempty(pythonFromEnv) || strlength(pythonFromEnv) == 0
                if ispc
                    test.python = "py";
                else
                    test.python = "python3";
                end
            else
                test.python = pythonFromEnv;
            end
            findIt = sprintf("%s --version", test.python);
            [status,output] = system(findIt);
            test.verifyTrue(status == 0, test.python + ": " + string(output));
            pythonPat = "Python" + whitespacePattern + ...
                asManyOfPattern(digitsPattern + ".") + digitsPattern;
            test.verifyTrue(contains(output, pythonPat), ...
                test.python + " --version failed to print Python version");
        end
    end

    methods
        function stopMcpServer(test, port)
        % Stop the mock server listening on PORT, by default the latest.
            arguments
                test
                port double = test.port
            end
            stop = sprintf("http://%s:%d/stop", MockCaller.Host, port);
            % Ignore errors during shutdown. 
            try
                webwrite(stop,[]);
            catch
            end
        end

        function n = requestCount(test,method,path)
        % Number of requests the mock server has received for "METHOD path".
        % The only externally observable way to tell whether the client
        % retried: a deterministic rejection must be sent exactly once.
            stats = webread(sprintf("http://%s:%d/stats", MockCaller.Host, test.port));
            key = matlab.lang.makeValidName(method + " " + path);
            if isstruct(stats) && isfield(stats,key)
                n = stats.(key);
            else
                n = 0;
            end
        end

        function endpoint = startMcpServer(test,config,opts)
        % Start the mock server on CONFIG. threaded=true answers requests
        % at the same time, as MATLAB Production Server does, so a slow
        % answer doesn't hold up the requests after it.
            arguments
                test
                config
                opts.threaded (1,1) logical = false
            end
            % A relative CONFIG is the test's own: beside its class file,
            % whatever the current folder. The mock runs in a window of its
            % own, so a file it can't find would show only as a timeout.
            config = string(config);
            if ~isfile(config) || ~test.isAbsolute(config)
                beside = fullfile(fileparts(which(class(test))), config);
                if isfile(beside)
                    config = beside;
                end
            end
            test.assertTrue(isfile(config), "No mock configuration " + config);
            config = """" + config + """";
            getPort ="import socket ; s = socket.socket ( socket.AF_INET, socket.SOCK_STREAM ) ; s.bind ( ( '', 0 ) ) ; print ( s.getsockname ( ) [1] ) ; s.close ( ) ";
            cmd = sprintf("%s -c ""%s""", test.python, getPort);
            [ok,output] = system(cmd);
            if ok == 0
                test.port = str2double(output);
            else
                error("MockCaller:NoFreePort", "%s", output);
            end
            flags = "";
            if opts.threaded
                flags = " --threaded";
            end
            cmd = sprintf("%s %s %s --host %s --port %d%s && exit&", test.python, test.server, ...
                config, MockCaller.Host, test.port, flags);
            [ok,msg] = system(cmd);
            endpoint = sprintf("http://%s:%d/mcp", MockCaller.Host, test.port);
            if ok ~= 0
                error("MockCaller:ServerStartFailed", "%s", msg);
            end
            % Wait until the server responds to a ping with 200. Python
            % can take more than 10 seconds to start when runClientTests
            % runs four test classes at once; the wait ends at the first
            % pong, so a generous limit costs nothing.
            timeout = 30;  % Seconds
            t = tic;
            pong = "";
            ping = sprintf("http://%s:%d/ping", MockCaller.Host, test.port);
            while toc(t) <= timeout 
                try
                    pong = webread(ping);
                    if strcmpi(pong,"pong") 
                        break;
                    end
                catch 
                end
                pause(1);
            end

            % Paranoia: server didn't send "pong" but started anyway. Need
            % to be able to tear it down. Protected webwrite() in
            % stopMcpServer prevents teardown from failing on servers that
            % never started. Hard to say which is the best tradeoff -- but
            % this way there should be fewer zombie processes. This server's
            % port, not test.port when the teardown runs: a test that starts
            % a second server moves test.port to it, and the first server
            % was never stopped.
            test.addTeardown(@stopMcpServer,test,test.port);

            % Be precise about reason for failure: timeout is different
            % than the wrong result from ping.
            test.assertLessThanOrEqual(toc(t),timeout,"Server timeout");
            test.assertEqual(string(pong),"pong", "Wrong return from ping");

            test.waitForServer();
        end
    end

    methods (Access = private)
        function tf = isAbsolute(~, f)
            tf = startsWith(f, ["/", "\"]) || ...
                ~isempty(regexp(f, "^[A-Za-z]:[\\/]", "once"));
        end

        function waitForServer(test)
        % system(... &) launches the mock in the background and returns at
        % once, before the mock listens. Some tests begin with a request
        % that does not retry a refused connection (requestCount, for one),
        % so wait for the mock to answer. On Linux a refusal is immediate;
        % on Windows it takes ~2 s, which hid this race. Then warm up
        % matlab.net.http: its first request in a session takes ~1.5 s,
        % which would eat most of a timing test's margin.
            stats = sprintf("http://%s:%d/stats", MockCaller.Host, test.port);
            for k = 1:50
                try
                    webread(stats);
                    warm = matlab.net.http.RequestMessage('GET');
                    send(warm, matlab.net.URI(stats));
                    return
                catch
                    pause(0.2);
                end
            end
            test.assertFail("Mock server did not start at " + stats);
        end
    end
end
