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

        function tNoBuildWhenNotDeployed(test)
            % Only a deployed archive has a build to name. The deployed
            % header is checked by tDeployOverwrite.
            response = prodserver.mcp.internal.pingHandler(struct());
            test.verifyFalse(any(strcmpi(response.Headers(:,1), ...
                prodserver.mcp.internal.Constants.ArchiveUUIDHeader)));
        end

    end

end
