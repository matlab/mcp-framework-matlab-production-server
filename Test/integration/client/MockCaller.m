classdef MockCaller < matlab.unittest.TestCase

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        port = 50101
        server = fullfile(fileparts(mfilename("fullpath")), ...
            "..", "..", "mocks", "server", "mock_server.py");
    end

    methods
        function stopMcpServer(test)
            stop = sprintf("http://localhost:%d/stop",test.port);
            webwrite(stop,[]);
        end

        function endpoint = startMcpServer(test,config)
            python = "python3";
            getPort = "import socket ; s = socket.socket ( socket.AF_INET, socket.SOCK_STREAM ) ; s.bind ( ( '', 0 ) ) ; print ( s.getsockname ( ) [1] ) ; s.close ( ) ";
            cmd = sprintf("%s -c ""%s""", python, getPort);
            [ok,output] = system(cmd);
            if ok == 0
                test.port = str2double(output);
            else
                error(output);
            end
            cmd = sprintf("%s %s %s --port %d &", python, test.server, ...
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
