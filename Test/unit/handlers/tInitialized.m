classdef tInitialized < matlab.unittest.TestCase
% Test prodserver.mcp.handler.notifications.initialized (the
% notifications/initialized notification: 202 Accepted, no body).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tReturns202NoBody(test)
            [result, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.notifications.initialized(struct());
            test.verifyEqual(httpCode, 202);
            test.verifyEqual(httpMsg, 'Accepted');
            test.verifyEmpty(result);
            test.verifyEmpty(msgHeaders);
        end

    end

end
