classdef MockCaller < matlab.unittest.TestCase

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
            cmd = sprintf("%s %s %s --port %d &", python, test.server, ...
            config, test.port);
            [ok,msg] = system(cmd);
            endpoint = sprintf("http://localhost:%d/mcp",test.port);

            test.addTeardown(@stopMcpServer,test);
        end
    end
end
