classdef tClientV20260728 < MockCaller
% Test client functions against a mock server speaking MCP 2026-07-28.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        Endpoint
    end

    methods (TestMethodSetup)
        function startServer(test)
            config = fullfile(fileparts(mfilename("fullpath")), ...
                "tClientV20260728.yaml");
            test.Endpoint = test.startMcpServer(config);
            prodserver.mcp.client.Adapter.create(action="clearAll");
        end
    end

    methods (Test)

        function tListTools(test)
            tools = prodserver.mcp.list(test.Endpoint, "Tool", ...
                protocol="2026-07-28");
            test.verifyNotEmpty(tools);
            test.verifyEqual(string(tools{1}.name), "addNumbers");
        end

        function tListResources(test)
            resources = prodserver.mcp.list(test.Endpoint, "Resource", ...
                protocol="2026-07-28");
            test.verifyNotEmpty(resources);
            test.verifyEqual(string(resources{1}.name), "hello");
        end

        function tListUnknownServer(test)
            % The mock answers 404 for any path it has no route for.
            missing = replace(test.Endpoint, "/mcp", "/missing/mcp");
            test.verifyError(@()prodserver.mcp.list(missing, "Tool", ...
                protocol="2026-07-28"), "prodserver:mcp:UnknownServer");
        end

        function tReadResource(test)
            result = prodserver.mcp.read(test.Endpoint, ...
                "mcp://test/hello", protocol="2026-07-28");
            test.verifyEqual(result, "Hello from MCP 2026-07-28!");
        end

        function tExist(test)
            tf = prodserver.mcp.exist(test.Endpoint, ...
                "addNumbers", "Tool", protocol="2026-07-28");
            test.verifyTrue(tf);
        end

        function tExistList(test)
        % One call, several identifiers: tf matches identifier in size, and each
        % identifier is checked against the list for its own type.
            tf = prodserver.mcp.exist(test.Endpoint, ...
                ["addNumbers", "noSuchTool", "mcp://test/hello"], ...
                ["Tool", "Tool", "Resource"], protocol="2026-07-28");
            test.verifyEqual(tf, [true false true]);

            % A scalar type applies to every identifier.
            tf = prodserver.mcp.exist(test.Endpoint, ...
                ["noSuchTool"; "addNumbers"], "Tool", protocol="2026-07-28");
            test.verifyEqual(tf, [false; true]);
        end

        function tAutoDetectSelectsV20260728(test)
            client = prodserver.mcp.client.Adapter.create( ...
                test.Endpoint, protocol="discover");
            test.verifyEqual(client.Version, "2026-07-28");
        end

    end

end
