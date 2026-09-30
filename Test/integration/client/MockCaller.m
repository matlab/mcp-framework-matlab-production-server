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
            webwrite(stop,[]);
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
            test.addTeardown(@stopMcpServer,test);
        end
    end
end
