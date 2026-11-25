classdef tAppCI < prodserver.mcp.test.base.MCPCaller
% Build an archive with an MCP App, deploy it, and check what clients see.
% MCPCaller finds the server (MW_MCP_MPS_TEST_SERVER) and checks its health.

% Copyright 2026 The MathWorks, Inc.

    properties
        endpoint
        archive = "appIntegration"
    end

    properties (Constant)
        % A client that declares MCP Apps support, as JSON.
        AppCaps = "{""extensions"":{""io.modelcontextprotocol/ui"":" + ...
            "{""mimeTypes"":[""text/html;profile=mcp-app""]}}}"
    end

    methods (TestClassSetup)

        function initPath(test)
            test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());
        end

        function deployWithApp(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % A failed setup method doesn't stop the next one: without a
            % server, stop here rather than build and deploy to nowhere.
            test.assertNotEmpty(test.server, "No test server: see " + ...
                prodserver.mcp.MCPConstants.TestServerEnvVar + ".");

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);

            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, test.archive));

            appFile = fullfile(tFolder.Folder, "mcp-app.html");
            fid = fopen(appFile, "w");
            fprintf(fid, "<html><body>integration test</body></html>");
            fclose(fid);

            ctf = prodserver.mcp.build("toyToolOne", ...
                folder=tFolder.Folder, archive=test.archive, ...
                app=appFile);

            test.endpoint = prodserver.mcp.deploy( ...
                ctf, test.host, test.port);
        end

    end

    methods (Test)

        function tResourceListed(test)
        % resources/list includes a ui:// resource with correct MIME type.

            import prodserver.mcp.MCPConstants

            resources = prodserver.mcp.list(test.endpoint, "Resource");
            uris = cellfun(@(r) string(r.uri), resources);
            idx = startsWith(uris, "ui://");
            test.verifyTrue(any(idx), "No ui:// resource in list");

            appRes = resources{find(idx, 1)};
            test.verifyEqual(string(appRes.mimeType), ...
                MCPConstants.AppResourceMimeType);
        end

        function tResourceServed(test)
        % resources/read returns HTML content for the app resource.

            resources = prodserver.mcp.list(test.endpoint, "Resource");
            uris = cellfun(@(r) string(r.uri), resources);
            idx = find(startsWith(uris, "ui://"), 1);

            % read finds a resource by its URI, not its name.
            content = prodserver.mcp.read(test.endpoint, ...
                resources{idx}.uri);

            test.verifyTrue(contains(content, "<html>"), ...
                "Resource content should be HTML");
        end

        function tToolHasMetaUI(test)
        % tools/list links the view to the user tool, and to no other tool.
        % jsondecode names the _meta field x_meta.

            json = rawJrpcCallWithSession(test, "tools/list");

            test.verifyFalse(contains(json, '"x_meta"'), ...
                "The MATLAB field name x_meta must not appear in JSON output");
            test.verifyFalse(contains(json, '"ui/resourceUri"'), ...
                "The deprecated flat key ui/resourceUri must not be used");

            tools = jsondecode(json).result.tools;
            if isstruct(tools)
                tools = num2cell(tools);
            end
            for n = 1:numel(tools)
                t = tools{n};
                hasUri = isfield(t, "x_meta") && isfield(t.x_meta, "ui") && ...
                    isfield(t.x_meta.ui, "resourceUri");
                if string(t.name) == "toyToolOne"
                    test.verifyTrue(hasUri, "toyToolOne should have _meta.ui.resourceUri");
                    if hasUri
                        test.verifyEqual(string(t.x_meta.ui.resourceUri), test.viewUri(), ...
                            "resourceUri should name the served view");
                    end
                else
                    test.verifyFalse(hasUri, string(t.name) + " should have no resourceUri");
                end
            end
        end

        function tInitializeAdvertisesExtension(test)
        % initialize response JSON contains io.modelcontextprotocol/ui.

            import prodserver.mcp.MCPConstants

            json = rawJrpcCall(test, "initialize", ...
                struct("protocolVersion", "2025-06-18", ...
                       "capabilities", struct(), ...
                       "clientInfo", struct("name","test","version","1.0")));

            test.verifyTrue(contains(json, MCPConstants.UIExtension_JSON), ...
                "initialize should advertise " + MCPConstants.UIExtension_JSON);
            test.verifyFalse(contains(json, MCPConstants.UIExtension_Field), ...
                "Alias must not appear in JSON output");
        end

        function tUri2jsonForAppHosts(test)
        % A client that declares MCP Apps support is offered uri2json, marked
        % app-only, and can call it: under both revisions.
            for protocol = ["2025-06-18", "2026-07-28"]
                session = test.startSession(protocol, test.AppCaps);
                [status, json] = test.post(protocol, "tools/list", "{}", ...
                    session=session, caps=test.AppCaps);
                test.verifyEqual(status, 200, protocol);
                t = test.listedTool(json, "uri2json");
                test.assertNotEmpty(t, protocol + ": uri2json not listed");
                test.verifyEqual(string(t.x_meta.ui.visibility), "app", protocol);
                test.verifyTrue(contains(json, '"visibility":["app"]'), ...
                    protocol + ": visibility must be a JSON array");

                [status, json] = test.post(protocol, "tools/call", ...
                    '{"name":"uri2json","arguments":{"uri":"' + test.viewUri() + '"}}', ...
                    session=session, caps=test.AppCaps);
                test.verifyEqual(status, 200, protocol);
                test.verifyTrue(contains(json, "integration test"), ...
                    protocol + ": the view's contents should come back; got " + json);
            end
        end

        function tUri2jsonHiddenFromOtherClients(test)
        % Any other client isn't offered uri2json, and calling it gets the
        % unknown-tool error, under both revisions.
            for protocol = ["2025-06-18", "2026-07-28"]
                session = test.startSession(protocol, "{}");
                [~, json] = test.post(protocol, "tools/list", "{}", session=session);
                test.verifyEmpty(test.listedTool(json, "uri2json"), protocol);
                test.verifyNotEmpty(test.listedTool(json, "toyToolOne"), protocol);

                [status, json] = test.post(protocol, "tools/call", ...
                    '{"name":"uri2json","arguments":{"uri":"' + test.viewUri() + '"}}', ...
                    session=session);
                test.verifyEqual(status, 200, protocol);
                decoded = jsondecode(json);
                test.verifyEqual(decoded.error.code, ...
                    prodserver.mcp.MCPConstants.ErrorInvalidParams, protocol);
                test.verifyFalse(contains(json, "integration test"), protocol);
            end
        end

        function tToolsListNotCached(test)
        % 2026-07-28: this app server's tools/list depends on the client, so
        % it isn't cached, by any client or gateway, whatever the client.
            for caps = [test.AppCaps, "{}"]
                [status, json] = test.post("2026-07-28", "tools/list", "{}", ...
                    caps=caps);
                test.verifyEqual(status, 200);
                r = jsondecode(json).result;
                test.verifyEqual(r.ttlMs, 0, caps);
                test.verifyEqual(string(r.cacheScope), "private", caps);
            end
        end

        function tUnknownSessionGets404(test)
        % 2025-06-18: a session ID this server didn't issue gets 404, and
        % the request isn't run.
            [status, json, echoed] = test.post("2025-06-18", "tools/call", ...
                '{"name":"toyToolOne","arguments":{"a":1,"b":2}}', ...
                session=string(matlab.lang.internal.uuid));
            test.verifyEqual(status, 404);
            decoded = jsondecode(json);
            test.verifyEqual(decoded.error.code, ...
                prodserver.mcp.protocol.v20250618.Constants.ErrorSessionNotFound);
            test.verifyFalse(isfield(decoded, "result"));
            test.verifyEqual(echoed, "", "The unknown session ID was echoed");
        end

        function tOversizedDeclaration(test)
        % A huge capabilities declaration still gives a session ID within
        % the budget, and the session works.
            big = '{"experimental":{"big":"' + string(repmat('x', 1, 4000)) + ...
                '"},"extensions":{"io.modelcontextprotocol/ui":{}}}';
            session = test.startSession("2025-06-18", big);
            test.verifyLessThanOrEqual(strlength(session), ...
                prodserver.mcp.protocol.v20250618.Constants.SessionTokenMaxLength);
            [status, json] = test.post("2025-06-18", "tools/list", "{}", session=session);
            test.verifyEqual(status, 200);
            test.verifyNotEmpty(test.listedTool(json, "uri2json"), ...
                "The reduced token should still declare MCP Apps support");
        end

    end

    methods (Access = private)
        function session = startSession(test, protocol, caps)
        % initialize under 2025-06-18, returning the session ID; nothing
        % under 2026-07-28, which has no sessions.
            session = "";
            if protocol == "2025-06-18"
                [status, ~, session] = test.post(protocol, "initialize", ...
                    '{"protocolVersion":"2025-06-18","capabilities":' + string(caps) + ...
                    ',"clientInfo":{"name":"test","version":"1.0"}}');
                test.assertEqual(status, 200, "initialize failed");
            end
        end

        function [status, json, session] = post(test, protocol, method, params, opts)
        % POST a JSON-RPC request written as JSON text, so that its field
        % names are exactly the wire names. PARAMS is a JSON object. Under
        % 2026-07-28 the request carries _meta, declaring opts.caps, and the
        % headers that revision requires; under 2025-06-18, opts.session.
        % Returns the HTTP status, the response text, and the response's
        % Mcp-Session-Id ("" if none).
            arguments
                test
                protocol (1,1) string
                method (1,1) string
                params (1,1) string
                opts.session (1,1) string = ""
                opts.caps (1,1) string = "{}"
            end
            import matlab.net.http.*
            import matlab.net.http.field.*

            params = strip(params);
            if protocol == "2026-07-28"
                meta = string('"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28",') + ...
                    '"io.modelcontextprotocol/clientCapabilities":' + opts.caps + '}';
                if params == "{}"
                    params = "{" + meta + "}";
                else
                    params = extractBefore(params, strlength(params)) + "," + meta + "}";
                end
            end
            body = '{"jsonrpc":"2.0","id":1,"method":"' + method + '","params":' + params + '}';

            fields = [ContentTypeField('application/json'), ...
                AcceptField('application/json')];
            if protocol == "2026-07-28"
                rows = [{prodserver.mcp.MCPConstants.ProtocolVersion, char(protocol)}; ...
                    prodserver.mcp.protocol.v20260728.messageHeaders(jsondecode(body))];
            elseif strlength(opts.session) > 0
                rows = {prodserver.mcp.protocol.v20250618.Constants.SessionId, ...
                    char(opts.session)};
            else
                rows = cell(0, 2);
            end
            for n = 1:size(rows, 1)
                fields(end+1) = HeaderField(rows{n,1}, rows{n,2}); %#ok<AGROW>
            end

            % Payload, not MessageBody(bytes): given bytes and a JSON content
            % type, MessageBody sends them as a JSON array of numbers.
            msg = MessageBody();
            msg.Payload = unicode2native(char(body), 'UTF-8');
            req = RequestMessage('POST', fields, msg);
            resp = req.send(matlab.net.URI(test.endpoint), ...
                HTTPOptions('ConvertResponse', false));
            status = double(resp.StatusCode);
            json = string(native2unicode(resp.Body.Data', 'UTF-8'));
            session = "";
            hdr = resp.getFields(prodserver.mcp.protocol.v20250618.Constants.SessionId);
            if ~isempty(hdr)
                session = string(hdr.Value);
            end
        end

        function t = listedTool(~, json, name)
        % The tools/list entry named NAME, decoded, or [] if it isn't listed.
            t = [];
            tools = jsondecode(json).result.tools;
            if isstruct(tools)
                tools = num2cell(tools);
            end
            for n = 1:numel(tools)
                if string(tools{n}.name) == name
                    t = tools{n};
                end
            end
        end

        function uri = viewUri(test)
            uri = "ui://" + test.archive + "/" + test.archive + ".html";
        end


        function [json, session] = rawJrpcCall(test, method, params)
        % Send a JSON-RPC request and return the raw JSON response text.
        % Uses matlab.net.http to avoid jsondecode on the response.

            import matlab.net.http.*
            import matlab.net.http.field.*
            import prodserver.mcp.MCPConstants

            body.jsonrpc = "2.0";
            body.id = 1;
            body.method = method;
            if nargin > 2
                body.params = params;
            else
                body.params = struct();
            end

            headers = [ContentTypeField('application/json'), ...
                       AcceptField('application/json')];

            httpOpts = HTTPOptions('ConvertResponse', false);
            uri = matlab.net.URI(test.endpoint);

            req = RequestMessage('POST', headers, MessageBody(body));
            resp = req.send(uri, httpOpts);
            prodserver.mcp.internal.requireSuccess(resp,uri);
            json = native2unicode(resp.Body.Data', 'UTF-8');

            session = "";
            % The session header belongs to the 2025-06-18 revision.
            hdr = resp.getFields(prodserver.mcp.protocol.v20250618.Constants.SessionId);
            if ~isempty(hdr)
                session = string(hdr.Value);
            end
        end

        function json = rawJrpcCallWithSession(test, method)
        % Initialize first, then send the method call using the session.

            import matlab.net.http.*
            import matlab.net.http.field.*
            import prodserver.mcp.MCPConstants

            initParams.protocolVersion = "2025-06-18";
            initParams.capabilities = struct();
            initParams.clientInfo.name = "test";
            initParams.clientInfo.version = "1.0";
            [~, session] = rawJrpcCall(test, "initialize", initParams);

            body.jsonrpc = "2.0";
            body.id = 2;
            body.method = method;
            body.params = struct();

            headers = [ContentTypeField('application/json'), ...
                       AcceptField('application/json')];
            if strlength(session) > 0
                headers = [headers, ...
                    matlab.net.http.HeaderField( ...
                        prodserver.mcp.protocol.v20250618.Constants.SessionId, char(session))];
            end

            httpOpts = HTTPOptions('ConvertResponse', false);
            uri = matlab.net.URI(test.endpoint);
            req = RequestMessage('POST', headers, MessageBody(body));
            resp = req.send(uri, httpOpts);
            prodserver.mcp.internal.requireSuccess(resp,uri);
            json = native2unicode(resp.Body.Data', 'UTF-8');
        end

    end

end
