classdef tCancelled < matlab.unittest.TestCase
% Test prodserver.mcp.handler.notifications.cancelled (the
% notifications/cancelled notification: 202 Accepted, no body, and every
% cancellation logged as RequestCancelled, its caller text through echo).

% Copyright 2026 The MathWorks, Inc.

    properties
        Captured    % LogCapture
    end

    methods (TestMethodSetup)
        function captureLog(test)
            % The handler is called directly, not through mcpHandler, so no
            % request starts: a fresh Log has no earlier request's context.
            test.Captured = test.applyFixture(prodserver.mcp.test.mixin.LogCapture());
        end
    end

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
            jrpc.params.requestId = 99;
            prodserver.mcp.handler.notifications.cancelled(jrpc);
            test.verifyEqual(test.Captured.Lines, "[mcp:information] prodserver:mcp:RequestCancelled " + ...
                "Request `99` cancelled: `user aborted`");
        end

        function tLogsReasonWithoutRequestId(test)
            % When no requestId is provided, the log uses "(unknown)".
            jrpc.jsonrpc = "2.0";
            jrpc.params.reason = "timeout";
            prodserver.mcp.handler.notifications.cancelled(jrpc);
            test.verifySubstring(test.Captured.Lines, "Request (unknown) cancelled: `timeout`");
        end

        function tLogsACancellationWithoutAReason(test)
            % MCP makes the reason optional: every cancellation is logged.
            jrpc.jsonrpc = "2.0";
            jrpc.params.requestId = 4;
            prodserver.mcp.handler.notifications.cancelled(jrpc);
            test.verifyEqual(test.Captured.Lines, "[mcp:information] prodserver:mcp:RequestCancelled " + ...
                "Request `4` cancelled: (no reason)");
        end

        function tMalformedMemberTypesAreTolerated(test)
            % XD10: neither member is guaranteed to be scalar text.
            jrpc.jsonrpc = "2.0";
            jrpc.params.reason = struct('why', 1);
            jrpc.params.requestId = [1 2 3];
            [r, c] = prodserver.mcp.handler.notifications.cancelled(jrpc);
            test.verifyEqual(c, 202);
            test.verifyEmpty(r);
            test.verifySubstring(test.Captured.Lines, ...
                "Request (unknown) cancelled: (unreadable reason)");
        end

        function tStringRequestIdIsLogged(test)
            jrpc.jsonrpc = "2.0";
            jrpc.params.reason = 'gone';
            jrpc.params.requestId = 'req-7';
            prodserver.mcp.handler.notifications.cancelled(jrpc);
            test.verifySubstring(test.Captured.Lines, "Request `req-7` cancelled: `gone`");
        end
    end

end
