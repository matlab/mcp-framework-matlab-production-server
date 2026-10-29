classdef tAdapters < matlab.unittest.TestCase
% Test client adapter classes for both protocol versions.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        AdapterVersion = struct( ...
            'v20250618', "2025-06-18", ...
            'v20260728', "2026-07-28")

        % Requests for the client/server header round trip: one method that
        % needs no Mcp-Name, each of the three that do, and a non-ASCII URI
        % that forces the Base64 sentinel -- the case where the header and
        % the body legitimately differ byte for byte, and so the one most
        % likely to be rejected by a server that compares them raw.
        NameCase = struct( ...
            'toolsList', struct( ...
                'method', "tools/list", 'params', struct()), ...
            'serverDiscover', struct( ...
                'method', "server/discover", 'params', struct()), ...
            'toolsCall', struct( ...
                'method', "tools/call", ...
                'params', struct('name', "myTool", ...
                                 'arguments', struct('x', 1))), ...
            'promptsGet', struct( ...
                'method', "prompts/get", ...
                'params', struct('name', "myPrompt")), ...
            'resourcesRead', struct( ...
                'method', "resources/read", ...
                'params', struct('uri', "res://data/1")), ...
            'nonAsciiUri', struct( ...
                'method', "resources/read", ...
                'params', struct('uri', ...
                    "res://caf" + string(char(233)) + "/data")), ...
            'sentinelLikeName', struct( ...
                'method', "tools/call", ...
                'params', struct('name', "=?base64?Zm9v?=")))
    end

    methods (Test)

        function tConstructionSetsEndpoint(test, AdapterVersion)
            endpoint = "http://localhost:9910/test/mcp";
            client = createClient(endpoint, AdapterVersion);
            test.verifyEqual(client.Endpoint, endpoint);
        end

        function tVersionConstant(test, AdapterVersion)
            client = createClient("http://localhost/mcp", AdapterVersion);
            test.verifyEqual(client.Version, AdapterVersion);
        end

        function tPrepareRequestStartsFromProtocolHeaders(test, AdapterVersion)
        % The per-connection headers are protocolHeaders', and prepareRequest
        % adds only per-message ones after them -- so the two cannot disagree
        % about the session id or the version.
            client = createClient("http://localhost/mcp", AdapterVersion);
            data = struct('jsonrpc', "2.0", 'id', 1, 'method', "tools/list");
            [~, headers] = client.prepareRequest(data);
            expected = client.protocolHeaders();
            test.verifyGreaterThanOrEqual(numel(headers), numel(expected));
            test.verifyEqual(string([headers(1:numel(expected)).Name]), ...
                string([expected.Name]));
            test.verifyEqual(string([headers(1:numel(expected)).Value]), ...
                string([expected.Value]));
        end

        function tNextIdIncrementsSequentially(test)
            client = prodserver.mcp.client.v20250618.Adapter( ...
                "http://localhost/mcp");
            test.verifyEqual(client.nextId(), 1);
            test.verifyEqual(client.nextId(), 2);
            test.verifyEqual(client.nextId(), 3);
        end

    end

    methods (Test, TestTags = {'v20250618'})

        function tV20250618PrepareRequestAddsSessionHeader(test)
            client = prodserver.mcp.client.v20250618.Adapter( ...
                "http://localhost/mcp");
            data = struct('jsonrpc', '2.0', 'method', 'tools/list');

            [outData, headers] = client.prepareRequest(data);

            test.verifyEqual(outData, data, ...
                "prepareRequest should not modify data for 2025-06-18");
            test.verifyClass(headers, 'matlab.net.http.HeaderField');
            test.verifyEqual(string(headers.Name), "Mcp-Session-Id");
        end

        function tV20250618ProtocolHeadersReturnsSessionHeader(test)
            client = prodserver.mcp.client.v20250618.Adapter( ...
                "http://localhost/mcp");
            headers = client.protocolHeaders();
            test.verifyClass(headers, 'matlab.net.http.HeaderField');
            test.verifyEqual(string(headers.Name), "Mcp-Session-Id");
        end

        function tV20250618PostEncodeIsNoOp(test)
            client = prodserver.mcp.client.v20250618.Adapter( ...
                "http://localhost/mcp");
            json = '{"_meta":{"io_modelcontextprotocol_protocolVersion":"2026-07-28"}}';
            test.verifyEqual(client.postEncode(json), json);
        end

    end

    methods (Test, TestTags = {'v20260728'})

        function tV20260728ConnectIsNoOp(test)
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");
            client.connect();
        end

        function tV20260728DisconnectIsNoOp(test)
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");
            client.disconnect();
        end

        function tV20260728PrepareRequestAddsMetaAndHeader(test)
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");
            data = struct('jsonrpc', '2.0', 'method', 'tools/list');

            [outData, headers] = client.prepareRequest(data);

            test.verifyTrue(isfield(outData.params, MCPConstants.MetaField));
            meta = outData.params.(MCPConstants.MetaField);
            test.verifyEqual(meta.(C.MetaProtocolVersion_Field), C.Version);
            test.verifyTrue(isfield(meta, C.MetaCapabilities_Field));

            % Two headers as of Phase 3, not one: this revision requires
            % Mcp-Method on every request and the server now rejects its
            % absence. tools/list names nothing, so Mcp-Name is correctly
            % absent here -- tV20260728PrepareRequestAddsNameHeader covers
            % the methods that do.
            test.verifyClass(headers, 'matlab.net.http.HeaderField');
            test.verifyEqual(arrayfun(@(h) string(h.Name), headers), ...
                ["MCP-Protocol-Version", C.McpMethod]);
            test.verifyEqual(arrayfun(@(h) string(h.Value), headers), ...
                ["2026-07-28", "tools/list"]);
        end

        function tV20260728PrepareRequestAddsNameHeader(test)
        % Mcp-Name, for each of the three methods that name a thing and for
        % the body field each one names it in. A client that omits this
        % earns -32020/400 from a strict server on a request whose body was
        % perfectly well formed, which is why it is asserted per method
        % rather than once.
            C = prodserver.mcp.protocol.v20260728.Constants;
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");

            % {method, params struct, expected Mcp-Name value}
            cases = {
                "tools/call",    struct('name', "myTool"),       "myTool"
                "prompts/get",   struct('name', "myPrompt"),     "myPrompt"
                "resources/read", struct('uri', "res://data/1"), "res://data/1"
                };

            for k = 1:size(cases,1)
                data = struct('jsonrpc', '2.0', ...
                    'method', char(cases{k,1}), 'params', cases{k,2});
                [~, headers] = client.prepareRequest(data);

                names = arrayfun(@(h) string(h.Name), headers);
                idx = find(names == C.McpName);
                test.assertNotEmpty(idx, ...
                    cases{k,1} + " must carry an " + C.McpName + " header");
                test.verifyEqual(string(headers(idx).Value), cases{k,3}, ...
                    "Mcp-Name value for " + cases{k,1});
            end
        end

        function tV20260728PrepareRequestEncodesNonAsciiName(test)
        % A URI that cannot travel as a plain header value goes out wrapped
        % in the Base64 sentinel. Asserted here as well as in
        % tHeaderSentinel because the question is not only whether the
        % encoder works but whether the client actually calls it.
            C = prodserver.mcp.protocol.v20260728.Constants;
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");

            uri = "res://caf" + string(char(233)) + "/data";
            data = struct('jsonrpc', '2.0', 'method', 'resources/read', ...
                'params', struct('uri', uri));
            [~, headers] = client.prepareRequest(data);

            names = arrayfun(@(h) string(h.Name), headers);
            sent = string(headers(names == C.McpName).Value);
            test.verifyTrue(startsWith(sent, C.HeaderSentinelPrefix), ...
                "a non-ASCII URI must be sent encoded, got: " + sent);
            test.verifyEqual( ...
                prodserver.mcp.protocol.v20260728.decodeHeaderValue(sent), ...
                uri);
        end

        function tV20260728PrepareRequestOmitsNameWhenBodyHasNone(test)
        % The deliberate no-else in prepareRequest. A tools/call with no
        % params.name is malformed, and inventing a header value would
        % convert the server's precise -32602 about the missing field into
        % a -32020 about a header the caller never set.
            C = prodserver.mcp.protocol.v20260728.Constants;
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");

            data = struct('jsonrpc', '2.0', 'method', 'tools/call', ...
                'params', struct('arguments', struct('x', 1)));
            [~, headers] = client.prepareRequest(data);

            names = arrayfun(@(h) string(h.Name), headers);
            test.verifyFalse(any(names == C.McpName), ...
                "no name in the body means no Mcp-Name header");
        end

        function tV20260728PreparedRequestPassesServerValidation(test, NameCase)
        %tV20260728PreparedRequestPassesServerValidation The round trip.
        %   What the client emits must satisfy what the server demands. The
        %   two sides are deliberately built on the same nameFromParams and
        %   encodeHeaderValue, so this test cannot catch a shared defect in
        %   the rule itself -- tHeaderSentinel pins the wire format against
        %   literal bytes for that. What this catches is the other failure,
        %   the one Phase 3 was opened by: the two sides disagreeing about
        %   which headers exist at all.
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");
            data = struct('jsonrpc', '2.0', ...
                'method', char(NameCase.method), 'params', NameCase.params);

            [outData, headers] = client.prepareRequest(data);

            % The HeaderField array the client sends, in the Nx2 cell shape
            % the server reads headers from.
            rows = cell(numel(headers), 2);
            for k = 1:numel(headers)
                rows{k,1} = char(headers(k).Name);
                rows{k,2} = char(headers(k).Value);
            end
            request = struct('Headers', {rows});

            try
                prodserver.mcp.protocol.v20260728.validateHeaders( ...
                    request, outData, ...
                    prodserver.mcp.protocol.v20260728.Constants.Version);
            catch me
                test.verifyFail("a client-built " + NameCase.method + ...
                    " request was rejected by the server: " + ...
                    me.identifier + " -- " + me.message);
            end
        end

        function tV20260728PrepareRequestPreservesExistingParams(test)
            import prodserver.mcp.MCPConstants

            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");
            data.jsonrpc = "2.0";
            data.method = "resources/read";
            data.params.uri = "mcp://test/resource";

            [outData, ~] = client.prepareRequest(data);

            test.verifyEqual(outData.params.uri, "mcp://test/resource");
            test.verifyTrue(isfield(outData.params, MCPConstants.MetaField));
        end

        function tV20260728ProtocolHeadersReturnsVersionHeader(test)
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");
            headers = client.protocolHeaders();
            test.verifyClass(headers, 'matlab.net.http.HeaderField');
            test.verifyEqual(string(headers.Name), "MCP-Protocol-Version");
            test.verifyEqual(string(headers.Value), "2026-07-28");
        end

        function tV20260728PostEncodeReplacesSubfields(test)
            C = prodserver.mcp.protocol.v20260728.Constants;
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");

            json = '{"_meta":{"io_modelcontextprotocol_protocolVersion":"2026-07-28"}}';
            result = client.postEncode(json);

            test.verifyTrue(contains(result, C.MetaProtocolVersion_JSON));
            test.verifyFalse(contains(result, C.MetaProtocolVersion_Field));
        end

        function tV20260728PostEncodeReplacesAllSixPairs(test)
            C = prodserver.mcp.protocol.v20260728.Constants;
            client = prodserver.mcp.client.v20260728.Adapter( ...
                "http://localhost/mcp");

            fields = {
                C.MetaProtocolVersion_Field
                C.MetaCapabilities_Field
                C.MetaClientInfo_Field
                C.MetaLogLevel_Field
                C.MetaServerInfo_Field
                C.MetaSubscriptionId_Field
            };
            jsonFields = {
                C.MetaProtocolVersion_JSON
                C.MetaCapabilities_JSON
                C.MetaClientInfo_JSON
                C.MetaLogLevel_JSON
                C.MetaServerInfo_JSON
                C.MetaSubscriptionId_JSON
            };

            for i = 1:numel(fields)
                json = sprintf('{"%s":"test"}', char(fields{i}));
                result = client.postEncode(json);
                test.verifyTrue(contains(result, jsonFields{i}), ...
                    sprintf("postEncode should replace %s", char(fields{i})));
                test.verifyFalse(contains(result, fields{i}));
            end
        end

    end

end

function client = createClient(endpoint, version)
    switch version
        case "2025-06-18"
            client = prodserver.mcp.client.v20250618.Adapter(endpoint);
        case "2026-07-28"
            client = prodserver.mcp.client.v20260728.Adapter(endpoint);
    end
end
