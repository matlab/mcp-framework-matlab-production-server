classdef tCancelled < matlab.unittest.TestCase
% Test prodserver.mcp.handler.notifications.cancelled (the
% notifications/cancelled notification: 202 Accepted, no body, optional
% logging of the cancellation reason).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tReturns202NoBody(test)
            jrpc.jsonrpc = "2.0";
            [result, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.notifications.cancelled(jrpc);
            test.verifyEqual(httpCode, 202);
            test.verifyEqual(httpMsg, 'Accepted');
            test.verifyEmpty(result);
            test.verifyEmpty(msgHeaders);
        end

        function tLogsReasonWithRequestId(test)
            jrpc.jsonrpc = "2.0";
            jrpc.params.reason = "user aborted";
            jrpc.params.requestId = 99; %#ok<STRNU> % used via evalc below
            log = evalc("prodserver.mcp.handler.notifications.cancelled(jrpc);");
            test.verifyTrue(contains(log, "Request 99 cancelled: user aborted"));
        end

        function tLogsReasonWithoutRequestId(test)
            % When no requestId is provided, the log uses "(unknown)".
            jrpc.jsonrpc = "2.0";
            jrpc.params.reason = "timeout"; %#ok<STRNU> % used via evalc below
            log = evalc("prodserver.mcp.handler.notifications.cancelled(jrpc);");
            test.verifyTrue(contains(log, "Request (unknown) cancelled: timeout"));
        end

    end

end
