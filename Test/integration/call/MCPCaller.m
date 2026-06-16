classdef MCPCaller < matlab.unittest.TestCase
% Base class for tests that invoke deployed MCP tools

    properties
        server       % Full address of the server
        host         % Host name extracted from server
        port         % Port number of server, may be empty
        toolFolder   % Where to find the tools
        tempFolder   % Where to put generated artifacts and other junk
        dataFolder   % A folder accessible to the server
    end

    methods
        function setFolders(test,opt)
            arguments
                test matlab.unittest.TestCase
                opt.temp string = string.empty
                opt.data string = string.empty
            end
            import prodserver.mcp.MCPConstants
            
            % Only set the temp folder if it was provided as input
            if ~isempty(opt.temp)
                test.tempFolder = opt.temp;
            end

            % The data folder may be set by an environment variable.
            if isempty(opt.data)
                dataF = getenv(MCPConstants.TestDataFolderEnvVar);
                if isempty(dataF) 
                    if ~isempty(opt.temp)
                        test.dataFolder = opt.temp;
                    end
                else
                    test.dataFolder = dataF;
                end
            else
                test.dataFolder = opt.data;
            end
        end
    end


    methods(TestClassSetup)

        function requireActiveServer(test)
            % The environment variable MW_MCP_MPS_TEST_SERVER must be set
            % to a valid, active MPS server instance endpoint.
            import prodserver.mcp.MCPConstants

            test.server = getenv(MCPConstants.TestServerEnvVar);

            test.assertTrue(~isempty(test.server), ...
      "Set environment variable " + MCPConstants.TestServerEnvVar + ...
      " to network address of MPS instance to be used for testing.");

            healthQuery = test.server + "/api/health";
            response = webread(healthQuery);
            test.assertTrue(strcmp(response.status,"ok"), ...
                "Invalid response to health query " + healthQuery + ": " + ...
                response.status);

            % Extract host and port from the server address
            hostPattern = lookBehindBoundary(textBoundary("start") + wildcardPattern("Except",":") + ...
                "://") + wildcardPattern("Except",":") + ...
                lookAheadBoundary(characterListPattern(":/") | ...
                    textBoundary("end"));
            test.host = string(extract(test.server,hostPattern));
            portPattern = lookBehindBoundary(wildcardPattern + test.host + ":") + ...
                wildcardPattern + textBoundary("end");
            test.port = string(extract(test.server,portPattern));
        end

        function managePath(test)
            import matlab.unittest.fixtures.PathFixture

            testFolder = fileparts(mfilename("fullpath"));
            test.toolFolder = fullfile(testFolder,"..","..","tools", ...
                "toyTools");

            % Test tools folder onto the path
            test.applyFixture(PathFixture(test.toolFolder));
        end

    end

end
