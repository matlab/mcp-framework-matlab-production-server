classdef tPingHandler < matlab.unittest.TestCase
% Test prodserver.mcp.internal.pingHandler (respond to <archive>/ping with a
% 200 'OK' text/plain 'pong' response).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tReturnsPongResponse(test)
            import prodserver.mcp.internal.pingHandler
            response = pingHandler(struct());
            test.verifyEqual(response.HttpCode, 200);
            test.verifyEqual(response.HttpMessage, 'OK');
            test.verifyEqual(string(char(response.Body)), ...
                prodserver.mcp.MCPConstants.Pong);
        end

    end

end
