classdef (Abstract) tMethodConformance < prodserver.mcp.test.base.MCPCaller
%tMethodConformance Spec-conformance of MCP JSON-RPC methods.
%   Deploys a single tool (primeSequence) once per class, then issues one
%   raw JSON-RPC request per MCP method and asserts the MCP specification's
%   required response. Requests are sent through the connected client
%   adapter (so the protocol envelope -- session header or _meta -- is
%   correct) but bypass the high-level helpers so error responses can be
%   inspected without throwing.
%
%   Concrete subclasses fix the Protocol property and add the protocol's
%   discovery test point (server/discover for 2026-07-28, initialize-based
%   discovery for 2025-06-18).

% Copyright 2026 The MathWorks, Inc.

    properties (Abstract, Constant)
        % MCP protocol version negotiated for every request in the class.
        Protocol string

        % Expected HTTP status for a method-not-found error. 2025-06-18
        % carries JSON-RPC errors in the body over HTTP 200; 2026-07-28
        % returns an unknown/unimplemented method as HTTP 404. Each
        % subclass fixes this to match its protocol.
        MethodNotFoundHttpStatus double
    end

    properties (Access = protected)
        Endpoint string   % Deployed archive endpoint
        Archive  string   % Deployed archive name
        ToolName string   % Deployed tool name
        Client            % Connected client adapter for Protocol
    end

    methods (TestClassSetup)

        function deployPrimeTool(test)
        % Build and deploy the primeSequence tool once for the class.
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % primeSequence lives in Examples/Primes (three levels up from
            % Test/integration/call).
            baseFolder = fileparts(mfilename("fullpath"));
            examplesDir = fullfile(baseFolder, "..", "..", "..", ...
                "Examples", "Primes");
            test.applyFixture(PathFixture(examplesDir));

            tfolder = TemporaryFolderFixture;
            test.applyFixture(tfolder);

            test.ToolName = "primeSequence";
            % Archive name must NOT contain the substring "mcp": call.m
            % derives the signature endpoint with a global replace of "mcp"
            % -> "signature", which would mangle the archive segment too.
            % One per subclass (primeConform20260728, ...): the subclasses
            % may run at the same time, and each removes its archive when
            % it ends.
            test.Archive = "primeConform" + erase(test.Protocol, "-");
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, test.Archive));

            ctf = prodserver.mcp.build("primeSequence", ...
                folder=tfolder.Folder, archive=test.Archive, ...
                tool=test.ToolName, ...
                example=@() primeSequence(5, "Eisenstein"));
            test.assertNotEmpty(ctf);

            test.Endpoint = prodserver.mcp.deploy(ctf, test.host, test.port);

            % Gate on deployment readiness before issuing requests.
            test.assertTrue(prodserver.mcp.ping(test.Endpoint), ...
                "Deployed archive did not become responsive: " + test.Endpoint);
        end

    end

    methods (TestMethodSetup)

        function freshClient(test)
        % Reset any cached adapter and connect a client for this protocol.
        % create(protocol=...) does not connect, so establish the session
        % explicitly (a no-op for the 2026-07-28 protocol).
            prodserver.mcp.client.Adapter.create(test.Endpoint, action="clear");
            test.Client = prodserver.mcp.client.Adapter.create( ...
                test.Endpoint, protocol=test.Protocol);
            % require="Tool" establishes the 2025-06-18 session and matches
            % the archive's advertised primitive; the default require="None"
            % is mishandled by that revision's initialize handshake.
            test.Client.connect(require="Tool");
        end

    end

    methods (Test)

        function tIsMCPServer(test)
            % A live server is active. (It used to be inactive always:
            % webread's 'pong' is char, not string.)
            [tf, active] = prodserver.mcp.validation.isMCPserver(test.Endpoint);
            test.verifyTrue(tf, "An MCP address");
            test.verifyTrue(active, "Active");
        end

        function tToolsList(test)
        % tools/list returns the tool descriptors.
            resp = test.rawRequest("tools/list");
            test.verifyOkResult(resp, "tools/list", "tools");
        end

        function tToolsCall(test)
        % tools/call is exercised through the high-level client, which
        % marshals the input schema. Confirms the method works end to end.
            expected = primeSequence(5, "Eisenstein");
            actual = prodserver.mcp.call(test.Endpoint, test.ToolName, ...
                5, "Eisenstein");
            % Compare as vectors: JSON arrays carry no orientation, so a row
            % result round-trips back as a column.
            test.verifyEqual(actual(:), expected(:), "tools/call result mismatch");
        end

        function tResourcesList(test)
        % resources/list returns a (possibly empty) resources array.
            resp = test.rawRequest("resources/list");
            test.verifyOkResult(resp, "resources/list", "resources");
        end

        function tResourcesRead(test)
        % No resources are defined for a tool-only archive, so reading any
        % URI must be reported as a JSON-RPC error, not a silent empty
        % success.
            resp = test.rawRequest("resources/read", ...
                struct("uri", "mcp://prime/none"));
            test.verifyErrorResponse(resp, "resources/read");
        end

        function tResourcesTemplatesList(test)
        % The resources capability is advertised, so listing templates must
        % return a well-formed (possibly empty) resourceTemplates array.
            resp = test.rawRequest("resources/templates/list");
            test.verifyOkResult(resp, "resources/templates/list", ...
                "resourceTemplates");
        end

        function tResourcesSubscribe(test)
        % The resources.subscribe capability is not advertised, so subscribe
        % must be rejected as Method not found.
            resp = test.rawRequest("resources/subscribe", ...
                struct("uri", "mcp://prime/none"));
            test.verifyMethodNotFound(resp, "resources/subscribe");
        end

        function tResourcesUnsubscribe(test)
        % The resources.subscribe capability is not advertised, so
        % unsubscribe must be rejected as Method not found.
            resp = test.rawRequest("resources/unsubscribe", ...
                struct("uri", "mcp://prime/none"));
            test.verifyMethodNotFound(resp, "resources/unsubscribe");
        end

        function tPromptsList(test)
        % The prompts capability is not advertised, so prompts/list must be
        % rejected as Method not found.
            resp = test.rawRequest("prompts/list");
            test.verifyMethodNotFound(resp, "prompts/list");
        end

        function tPromptsGet(test)
        % The prompts capability is not advertised, so prompts/get must be
        % rejected as Method not found.
            resp = test.rawRequest("prompts/get", struct("name", "none"));
            test.verifyMethodNotFound(resp, "prompts/get");
        end

    end

    methods (Access = protected)

        function resp = rawRequest(test, method, params)
        % rawRequest Send a JSON-RPC request through the connected client
        %   adapter and return the raw HTTP response WITHOUT throwing on a
        %   non-2xx status, so error responses can be inspected.
            arguments
                test
                method (1,1) string
                params struct = struct.empty
            end

            client = test.Client;

            data.jsonrpc = prodserver.mcp.MCPConstants.jrpcVersion;
            data.method = method;
            data.id = client.nextId();
            if ~isempty(params)
                data.params = params;
            end

            % The client's own request: protocol envelope (session header
            % for 2025-06-18, _meta and headers for 2026-07-28) and the POST
            % headers it must send (G15). Only the send is done here, so
            % that a failing status is returned rather than raised.
            request = client.buildRequest(data);

            httpOptions = matlab.net.http.HTTPOptions( ...
                ConnectTimeout=60, ResponseTimeout=60);
            resp = request.send(matlab.net.URI(client.Endpoint), httpOptions);
        end

        function verifyOkResult(test, resp, label, field)
        % verifyOkResult Assert a successful JSON-RPC result: 2xx status, no
        %   error member, and (optionally) a named field under result.
            arguments
                test
                resp
                label (1,1) string
                field string = string.empty
            end
            import prodserver.mcp.internal.hasField

            sc = double(resp.StatusCode);
            ctx = " [" + test.describe(resp) + "]";
            test.verifyTrue(sc >= 200 && sc < 300, ...
                label + ": expected 2xx HTTP status, got " + string(sc) + ctx);
            test.verifyFalse(hasField(resp, "Body.Data.error"), ...
                label + ": response should not carry a JSON-RPC error" + ctx);
            if ~isempty(field)
                test.verifyTrue(hasField(resp, "Body.Data.result." + field), ...
                    label + ": result missing expected field '" + field + "'" + ctx);
            end
        end

        function verifyMethodNotFound(test, resp, label)
        % verifyMethodNotFound Assert the spec response for an unsupported
        %   method: a JSON-RPC error with code -32601 delivered over HTTP
        %   200 (a JSON-RPC error is not an HTTP transport error).
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            ctx = " [" + test.describe(resp) + "]";
            test.verifyEqual(double(resp.StatusCode), ...
                test.MethodNotFoundHttpStatus, ...
                label + ": method-not-found must use the protocol's HTTP " + ...
                "status (" + string(test.MethodNotFoundHttpStatus) + ")" + ctx);
            test.assertTrue(hasField(resp, "Body.Data.error.code"), ...
                label + ": response missing JSON-RPC error.code" + ctx);
            test.verifyEqual(double(resp.Body.Data.error.code), ...
                double(MCPConstants.ErrorMethodNotFound), ...
                label + ": expected JSON-RPC error code -32601 (Method not found)" + ctx);
        end

        function verifyErrorResponse(test, resp, label)
        % verifyErrorResponse Assert that an unfulfillable operation is
        %   signaled as a JSON-RPC error rather than a silent success.
            import prodserver.mcp.internal.hasField
            test.verifyTrue(hasField(resp, "Body.Data.error"), ...
                label + ": expected a JSON-RPC error response [" + ...
                test.describe(resp) + "]");
        end

        function s = describe(~, resp)
        % describe Compact HTTP-status + body summary for diagnostics.
            import prodserver.mcp.internal.hasField
            s = "HTTP " + string(double(resp.StatusCode));
            if hasField(resp, "Body.Data") && ~isempty(resp.Body.Data)
                try
                    body = string(jsonencode(resp.Body.Data));
                catch
                    body = string(class(resp.Body.Data)) + " body";
                end
                if strlength(body) > 300
                    body = extractBefore(body, 300) + "...";
                end
                s = s + ", body=" + body;
            end
        end

    end

end
