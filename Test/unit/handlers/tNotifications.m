classdef tNotifications < prodserver.mcp.test.base.MCPHandlerBase
% A JSON-RPC notification -- a request with no id member -- never gets a
% response body. JSON-RPC forbids replying to a request that has no id, so
% there is nobody to correlate a reply with and nobody to report an error to.
%
% The defect: an unknown notifications/* method raised
% prodserver:mcp:UnsupportedRequest and the handler formatted a JSON-RPC error
% reply for it, which a conforming client is entitled to treat as a protocol
% violation. 202 Accepted with an empty body is the only correct answer,
% whatever happens while handling the notification.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        notification = { ...
            'notifications/initialized', ...
            'notifications/cancelled', ...
            'notifications/progress', ...
            'notifications/roots/list_changed', ...
            'no/such/notification'};
    end

    methods

        function response = jrpcNotify(test, method, opts)
            arguments
                test
                method (1,1) string
                opts.session (1,1) string = "auto"
            end

            body = sprintf('{ "jsonrpc": "2.0", "method": "%s" }', method);
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, session=opts.session));
        end
    end

    methods (Test)

        function tNotificationIsAccepted(test, notification)
        % Known or unknown, handled or not: 202 and nothing else.
            response = test.jrpcNotify(notification);

            test.verifyEqual(response.HttpCode, 202);
            test.verifyEmpty(response.Body, ...
                "A notification must not receive a response body");
            test.verifyConformantResponse(response);
        end

        function tNotificationHasNoContentType(test, notification)
        % Content-Type describes a body. A 202 advertising application/json
        % promises a body that is not there -- which is exactly what the
        % handler used to do, because the header was appended whenever the
        % handler had declined to pre-encode a body rather than when a body
        % actually existed.
            response = test.jrpcNotify(notification);

            ct = prodserver.mcp.internal.getHeaderValue( ...
                prodserver.mcp.MCPConstants.ContentType, response.Headers);
            test.verifyEmpty(ct, ...
                "A bodiless 202 must not declare a Content-Type");
        end

        function tNotificationExemptFromSessionGate(test, notification)
        % Notifications are exempt from the missing-session 400 for the same
        % reason they get no error reply: a 400 is a reply. Several clients
        % also send notifications/initialized before they have stored the
        % session id from the initialize response.
            response = test.jrpcNotify(notification, session="omit");
            test.verifyEqual(response.HttpCode, 202);
            test.verifyEmpty(response.Body);
        end

        function tFailingNotificationStillAccepted(test)
        % notifications/cancelled with params that the handler cannot make
        % sense of must still be a bare 202, not an error reply.
            body = ['{ "jsonrpc": "2.0", "method": "notifications/cancelled", ' ...
                    '"params": "not-an-object" }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyEqual(response.HttpCode, 202);
            test.verifyEmpty(response.Body);
            test.verifyConformantResponse(response);
        end

        function tRequestWithIdIsNotANotification(test)
        % The contrast case, so the notification rule cannot be implemented by
        % simply suppressing every error body: the same method name with an id
        % present is a request and does get a reply.
            body = ['{ "jsonrpc": "2.0", "id": 1, ' ...
                    '"method": "no/such/notification" }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorMethodNotFound);
        end

    end
end
