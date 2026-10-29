classdef MockCaller < matlab.unittest.TestCase

% Copyright 2025-2026 The MathWorks, Inc.

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
            stop = sprintf("http://localhost:%d/stop",port);
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
            stats = webread(sprintf("http://localhost:%d/stats",test.port));
            key = matlab.lang.makeValidName(method + " " + path);
            if isstruct(stats) && isfield(stats,key)
                n = stats.(key);
            else
                n = 0;
            end
        end

        function endpoint = startMcpServer(test,config)
            getPort = "import socket ; s = socket.socket ( socket.AF_INET, socket.SOCK_STREAM ) ; s.bind ( ( '', 0 ) ) ; print ( s.getsockname ( ) [1] ) ; s.close ( ) ";
            cmd = sprintf("%s -c ""%s""", test.python, getPort);
            [ok,output] = system(cmd);
            if ok == 0
                test.port = str2double(output);
            else
                error("MockCaller:NoFreePort", "%s", output);
            end
            cmd = sprintf("%s %s %s --port %d && exit&", test.python, test.server, ...
                config, test.port);
            [ok,msg] = system(cmd);
            endpoint = sprintf("http://localhost:%d/mcp",test.port);
            if ok ~= 0
                error("MockCaller:ServerStartFailed", "%s", msg);
            end
            % Wait until the server responds to a ping with 200
            timeout = 10;  % Seconds
            t = tic;
            pong = "";
            ping = sprintf("http://localhost:%d/ping", test.port);
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
        function waitForServer(test)
        % system(... &) launches the mock in the background and returns at
        % once, before the mock listens. Some tests begin with a request
        % that does not retry a refused connection (requestCount, for one),
        % so wait for the mock to answer. On Linux a refusal is immediate;
        % on Windows it takes ~2 s, which hid this race. Then warm up
        % matlab.net.http: its first request in a session takes ~1.5 s,
        % which would eat most of a timing test's margin.
            stats = sprintf("http://localhost:%d/stats",test.port);
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
