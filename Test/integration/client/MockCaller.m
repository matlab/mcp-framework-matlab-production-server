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
        function stopMcpServer(test)
            stop = sprintf("http://localhost:%d/stop",test.port);
            % Ignore errors during shutdown.
            try
                webwrite(stop,[]);
            catch
            end
        end

        function endpoint = startMcpServer(test,config)
            getPort = "import socket ; s = socket.socket ( socket.AF_INET, socket.SOCK_STREAM ) ; s.bind ( ( '', 0 ) ) ; print ( s.getsockname ( ) [1] ) ; s.close ( ) ";
            cmd = sprintf("%s -c ""%s""", test.python, getPort);
            [ok,output] = system(cmd);
            if ok == 0
                test.port = str2double(output);
            else
                error(output);
            end
            cmd = sprintf("%s %s %s --port %d && exit&", test.python, test.server, ...
                config, test.port);
            [ok,msg] = system(cmd);
            endpoint = sprintf("http://localhost:%d/mcp",test.port);
            if ok ~= 0
                error(msg);
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
            % this way there should be fewer zombie processes.
            test.addTeardown(@stopMcpServer,test);

            % Be precise about reason for failure: timeout is different
            % than the wrong result from ping.
            test.assertLessThanOrEqual(toc(t),timeout,"Server timeout");
            test.assertEqual(string(pong),"pong", "Wrong return from ping");
        end
    end
end
