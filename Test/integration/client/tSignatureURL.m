classdef tSignatureURL < MockCaller
% prodserver.mcp.call finds a tool's signature next to its MCP endpoint: the
% final /mcp of the endpoint replaced with /signature, and nothing else.
%
% It used to replace every /mcp. An archive whose name starts with mcp, such
% as mcpAdd, then had its signature looked for at /signatureAdd/signature, as
% did any archive behind a proxy path that starts with /mcp: a 404, and no
% call at all.

% Copyright 2026 The MathWorks, Inc.

    methods(Test)

        function archiveNameStartsWithMcp(test)
            endpoint = test.archiveEndpoint("/mcpAdd");
            test.verifyEqual(prodserver.mcp.call(endpoint, "mcpAdd", 2, 3), 5);
            test.verifyEqual(test.requestCount("POST", "/mcpAdd/signature"), 1, ...
                "The signature is the archive's own.");
        end

        function proxyPathStartsWithMcp(test)
            endpoint = test.archiveEndpoint("/mcpgw/mcpAdd");
            test.verifyEqual(prodserver.mcp.call(endpoint, "mcpAdd", 2, 3), 5);
            test.verifyEqual(test.requestCount("POST", ...
                "/mcpgw/mcpAdd/signature"), 1, ...
                "The signature is behind the same proxy path.");
        end

    end

    methods (Access = private)

        function endpoint = archiveEndpoint(test, prefix)
        % The mock's endpoint, http://127.0.0.1:<port>/mcp, with PREFIX
        % before its /mcp.
            server = test.startMcpServer("tSignatureURL.yaml");
            endpoint = extractBefore(server, "/mcp" + textBoundary("end")) + ...
                prefix + "/mcp";
        end

    end

end
