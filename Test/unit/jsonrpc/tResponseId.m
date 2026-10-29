classdef tResponseId < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.responseId (choose the id to echo in a
% JSON-RPC response, falling back to the JSON null that the spec requires
% when the request id is unknown).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tNumericIdEchoed(test)
            jrpc = struct('jsonrpc', '2.0', 'id', 7, 'method', 'ping');
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId(jrpc), 7);
        end

        function tStringIdEchoed(test)
            % JSON-RPC permits a string id; it must round-trip unchanged.
            jrpc = struct('jsonrpc', '2.0', 'id', "abc", 'method', 'ping');
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId(jrpc), "abc");
        end

        function tMissingIdFieldIsNaN(test)
            jrpc = struct('jsonrpc', '2.0', 'method', 'ping');
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId(jrpc), NaN);
        end

        function tEmptyIdIsNaN(test)
            jrpc = struct('jsonrpc', '2.0', 'id', [], 'method', 'ping');
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId(jrpc), NaN);
        end

        function tEmptyJrpcIsNaN(test)
            % A parse failure never produces a struct, so responseId must
            % cope with the [] that mcpHandler initializes jrpc to.
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId([]), NaN);
        end

        function tNonStructIsNaN(test)
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId("garbage"), NaN);
        end

        function tStructArrayIsNaN(test)
            % A JSON-RPC batch body decodes to a struct ARRAY, and on an
            % array jrpc.id is a comma-separated list: without an isscalar
            % guard, isempty(jrpc.id) raised MATLAB:maxrhs. responseId runs
            % on the error path, so that crash escaped mcpHandler's own
            % catch and a batch POST reached the server as a raw MATLAB
            % error instead of the -32600 validateEnvelope had decided on.
            % There is no single id to echo for a batch: null is the answer.
            jrpc = struct('jsonrpc', {'2.0','2.0'}, 'id', {1,2}, ...
                'method', {'ping','ping'});
            test.verifyEqual(prodserver.mcp.jsonrpc.responseId(jrpc), NaN);
        end

        function tEncodesAsJsonNull(test)
            % The whole point of choosing NaN: jsonencode renders it as the
            % literal null that JSON-RPC 2.0 requires for an unknown id.
            % An id of [] would vanish from the object entirely.
            result.jsonrpc = "2.0";
            result.id = prodserver.mcp.jsonrpc.responseId([]);
            result.error.code = -32700;
            result.error.message = "Parse error";
            json = prodserver.mcp.jsonrpc.encodeMessage(result);
            test.verifyTrue(contains(json, '"id":null'), ...
                "Unknown id must encode as JSON null, got: " + json);
        end

        function tEmptyArrayStillEncodesAsArray(test)
            % Regression guard on choosing NaN over a blanket []->null rule:
            % an empty tools list must stay [] on the wire, because
            % tools/list with no tools is a legal empty array, not null.
            result.jsonrpc = "2.0";
            result.id = 1;
            result.result.tools = {};
            json = prodserver.mcp.jsonrpc.encodeMessage(result);
            test.verifyTrue(contains(json, '"tools":[]'), ...
                "An empty tools list must encode as [], got: " + json);
        end

    end

end
