classdef tMetricsErrors < MockCaller
% prodserver.mcp.metrics's errors for a metrics query that fails: an HTTP
% status is the server's answer, raised with MATLAB's identifier, not taken
% for a timeout; a refused connection is ServerUnresponsive and says so;
% and no message shows the address's user information.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Secret = "s3cr3tSENTINEL"
    end

    methods (Access = private)
        function verifyNoSecret(test, text)
            test.verifyFalse(contains(text, test.Secret), ...
                "Shows the password: " + text);
            test.verifyFalse(contains(text, "alice"), ...
                "Shows the user name: " + text);
        end
    end

    methods (Test)

        function gatewayTimeoutIsTheServersAnswer(test)
            % 504's reason phrase is "Gateway Timeout"; it isn't the
            % client's timeout, and it isn't resent.
            endpoint = test.startMcpServer("tMetricsErrors.yaml");
            server = replace(extractBefore(endpoint, "/mcp"), "://", ...
                "://alice:" + test.Secret + "@");
            err = captureError(@() prodserver.mcp.metrics(server, ...
                timeout=10, delay=0.1), 1);
            test.assertNotEmpty(err, "Expected an HTTP 504 error.");
            test.verifyEqual(string(err.identifier), ...
                "MATLAB:webservices:HTTP504StatusCodeError", err.message);
            test.verifyFalse(contains(err.message, "second timeout"), err.message);
            test.verifyNoSecret(err.message);
            test.verifyEqual(test.requestCount("GET", "/api/metrics"), 1);
        end

        function refusedConnectionIsUnresponsive(test)
            err = captureError(@() prodserver.mcp.metrics( ...
                "http://alice:" + test.Secret + "@localhost:1", ...
                timeout=5, delay=0.1), 1);
            test.assertNotEmpty(err, "Expected ServerUnresponsive.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:ServerUnresponsive", err.message);
            test.verifySubstring(err.message, "The connection was refused.");
            test.verifyNoSecret(err.message);
        end

        function unknownHostDoesNotShowThePassword(test)
            err = captureError(@() prodserver.mcp.metrics( ...
                "http://alice:" + test.Secret + "@no-such-host.invalid", ...
                timeout=5, delay=0.1), 1);
            test.assertNotEmpty(err, "Expected an error.");
            test.verifyNoSecret(err.message);
        end

    end
end
