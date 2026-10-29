classdef tValidateEnvelope < matlab.unittest.TestCase
% Test prodserver.mcp.internal.validateEnvelope (stage B' of the request
% pipeline: reject a body that parsed as JSON but is not a usable JSON-RPC
% 2.0 request object).

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ID = "prodserver:mcp:InvalidRequest";
    end

    methods

        function check(test, jrpc)
            test.verifyError( ...
                @() prodserver.mcp.internal.validateEnvelope(jrpc), test.ID);
        end

    end

    methods (Test)

        function tWellFormedPasses(test)
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'tools/list');
            test.verifyWarningFree( ...
                @() prodserver.mcp.internal.validateEnvelope(jrpc));
        end

        function tStringMembersPass(test)
            % jsondecode may yield char or string depending on the body; both
            % are legal here.
            jrpc = struct('jsonrpc', "2.0", 'id', "7", 'method', "ping");
            test.verifyWarningFree( ...
                @() prodserver.mcp.internal.validateEnvelope(jrpc));
        end

        function tNotAStruct(test)
            test.check([]);
            test.check("just a string");
            test.check(42);
        end

        function tNonScalarStruct(test)
            % A JSON-RPC batch decodes to a struct array. Batching is not
            % supported, and a batch is not a request object.
            jrpc = struct('jsonrpc', {'2.0', '2.0'}, 'id', {1, 2}, ...
                'method', {'ping', 'ping'});
            test.check(jrpc);
        end

        function tMissingJsonrpc(test)
            test.check(struct('id', 1, 'method', 'ping'));
        end

        function tEmptyJsonrpc(test)
            test.check(struct('jsonrpc', [], 'id', 1, 'method', 'ping'));
        end

        function tWrongJsonrpcVersion(test)
            test.check(struct('jsonrpc', '1.0', 'id', 1, 'method', 'ping'));
        end

        function tNumericJsonrpcRejected(test)
            % 2.0 as a JSON number is not the string "2.0" the spec mandates.
            test.check(struct('jsonrpc', 2.0, 'id', 1, 'method', 'ping'));
        end

        function tMissingMethod(test)
            test.check(struct('jsonrpc', '2.0', 'id', 1));
        end

        function tEmptyMethod(test)
            test.check(struct('jsonrpc', '2.0', 'id', 1, 'method', ''));
        end

        function tNonStringMethod(test)
            test.check(struct('jsonrpc', '2.0', 'id', 1, 'method', 17));
        end

        function tMissingId(test)
            % Notifications never reach validateEnvelope, so an id-less
            % message here is a malformed request, not a notification.
            test.check(struct('jsonrpc', '2.0', 'method', 'tools/list'));
        end

        function tNullId(test)
            % JSON null decodes to [].
            test.check(struct('jsonrpc', '2.0', 'id', [], 'method', 'ping'));
        end

        function tNotificationNeverReachesHere(test)
            % The carve-out ordering is the contract: validateEnvelope would
            % reject a well-formed notification for having no id, so
            % mcpHandler must never call it for one. Proven at the handler
            % level by tmcpHandler/notificationsInitializedIs202; asserted
            % here so the reason the two orderings cannot be swapped is
            % recorded next to the check that depends on it.
            notification = struct('jsonrpc', '2.0', 'method', ...
                'notifications/initialized');
            test.check(notification);
        end

    end

end
