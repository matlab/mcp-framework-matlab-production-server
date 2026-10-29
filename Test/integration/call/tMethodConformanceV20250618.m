classdef tMethodConformanceV20250618 < tMethodConformance
%tMethodConformanceV20250618 MCP method conformance for revision 2025-06-18.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Protocol = "2025-06-18"

        % 2025-06-18 carries a method-not-found error in the body over HTTP 200.
        MethodNotFoundHttpStatus double = 200
    end

    methods (Test)

        function tPing(test)
        % ping is a utility of the 2025-06-18 protocol and returns an empty
        % result object.
            resp = test.rawRequest("ping");
            test.verifyOkResult(resp, "ping");
        end

        function tServerDiscover(test)
        % server/discover is not part of the 2025-06-18 protocol -- capability
        % discovery happens through the initialize handshake -- so an explicit
        % server/discover request must be rejected as Method not found.
            resp = test.rawRequest("server/discover");
            test.verifyMethodNotFound(resp, "server/discover");
        end

    end

end
