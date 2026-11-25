classdef tSessionTokens < matlab.unittest.TestCase
% 2025-06-18 session IDs, end to end through mcpHandler: initialize issues a
% token carrying the client's capabilities, a request with a token is
% served, and a request with any other session ID gets 404, without its ID
% echoed and without being dispatched.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        UI = "io.modelcontextprotocol/ui"
    end

    properties (Access = private)
        baseRequest
    end

    methods (TestMethodSetup)
        function buildBaseRequest(test)
            test.baseRequest = struct( ...
                'ApiVersion', [1 0 0], ...
                'Headers', {{'Server' ...
                    'MATLAB Production Server/Model Context Protocol (v1.0)'}});
        end
    end

    methods (Test)

        function tInitializeIssuesToken(test)
        % The session ID carries the declared capabilities.
            response = test.initialize( ...
                '{"extensions":{"io.modelcontextprotocol/ui":{"mimeTypes":["text/html;profile=mcp-app"]}}}');
            test.verifyEqual(response.HttpCode, 200);
            token = test.sessionHeader(response);
            test.verifyTrue(startsWith(token, "v1."), token);
            test.verifyLessThanOrEqual(strlength(token), ...
                prodserver.mcp.protocol.v20250618.Constants.SessionTokenMaxLength);
            [~, caps, ok] = prodserver.mcp.protocol.v20250618.decodeSession(token);
            test.verifyTrue(ok);
            test.verifyTrue(supports(caps, test.UI));
        end

        function tInitializeWithoutExtension(test)
            token = test.sessionHeader(test.initialize('{}'));
            [~, caps, ok] = prodserver.mcp.protocol.v20250618.decodeSession(token);
            test.verifyTrue(ok);
            test.verifyFalse(supports(caps, test.UI));
        end

        function tIssuedSessionServed(test)
        % The ID initialize issued is accepted, and echoed, on later requests.
            token = test.sessionHeader(test.initialize('{}'));
            response = test.ping(token);
            test.verifyEqual(response.HttpCode, 200);
            test.verifyEqual(test.sessionHeader(response), string(token));
        end

        function tUnknownSessionGets404(test)
        % Any ID this server didn't issue: 404 with a JSON-RPC body, the
        % session-not-found code, no Mcp-Session-Id in the response, and no
        % result, because the request was never dispatched.
            b64 = @(s) char(prodserver.mcp.internal.base64encode( ...
                unicode2native(s, "UTF-8"), URLSafe=true));
            unknown = {char(matlab.lang.internal.uuid), 'abc-123', ...
                'v1.!!!', ['v1.' repmat('A', 1, 2000)], ...
                ['v1.' b64('{"sid":["a","b"],"caps":{}}')], ...
                ['v1.' b64(['{"sid":"a","caps":{"experimental":{"pad":"' ...
                    repmat('x', 1, 1100) '"}}}'])]};
            for n = 1:numel(unknown)
                label = extractBefore(string(unknown{n}) + blanks(24), 24);
                response = test.ping(unknown{n});
                test.verifyEqual(response.HttpCode, 404, label);
                decoded = prodserver.mcp.internal.decodeBody(response);
                test.verifyEqual(decoded.error.code, ...
                    prodserver.mcp.protocol.v20250618.Constants.ErrorSessionNotFound, label);
                test.verifyFalse(isfield(decoded, "result"), label);
                test.verifyEqual(test.sessionHeader(response), "", ...
                    "Unknown session ID echoed: " + label);
            end
        end

        function tDeleteUnknownSession(test)
            response = test.deleteSession(char(matlab.lang.internal.uuid));
            test.verifyEqual(response.HttpCode, 404);
            test.verifyEqual(test.sessionHeader(response), "");
        end

        function tDeleteIssuedSession(test)
            token = test.sessionHeader(test.initialize('{}'));
            response = test.deleteSession(token);
            test.verifyEqual(response.HttpCode, 204);
        end

        function tCapabilitiesReachHandlers(test)
        % The capabilities a session ID carries reach the handlers: on an
        % app server, tools/list includes uri2json only for a session that
        % declared MCP Apps support.
            import prodserver.mcp.protocol.v20250618.Constants
            test.seedAppDefinitions();
            cases = {'{"extensions":{"io.modelcontextprotocol/ui":{}}}', true; ...
                '{}', false};
            for n = 1:size(cases, 1)
                token = test.sessionHeader(test.initialize(cases{n,1}));
                response = test.post( ...
                    '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}', ...
                    {Constants.SessionId, char(token)});
                test.verifyEqual(response.HttpCode, 200, cases{n,1});
                tools = prodserver.mcp.internal.decodeBody(response).result.tools;
                if iscell(tools)
                    names = cellfun(@(t) string(t.name), tools);
                else
                    names = string({tools.name});
                end
                test.verifyTrue(ismember("toyToolOne", names), cases{n,1});
                test.verifyEqual(ismember("uri2json", names), cases{n,2}, ...
                    "uri2json listed for capabilities " + cases{n,1});
            end
        end

    end

    methods (Access = private)

        function seedAppDefinitions(test)
        % Make this an app server: a definition file with the app flag, a
        % user tool and uri2json. tools/list only looks at the names.
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.applyFixture(PathFixture(tFolder.Folder));
            def.(MCPConstants.DefinitionVariable).tools = { ...
                struct("name", "toyToolOne"), ...
                struct("name", MCPConstants.Uri2JsonTool)};
            def.(MCPConstants.ResourceVariable) = {};
            def.(MCPConstants.AppResourceVariable) = true;
            save(fullfile(tFolder.Folder, MCPConstants.DefinitionFile), ...
                "-struct", "def");
            % The definitions are cached; clear them now and afterwards.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));
        end

        function response = initialize(test, capabilities)
            body = ['{"jsonrpc":"2.0","id":1,"method":"initialize","params":' ...
                '{"protocolVersion":"2025-06-18","capabilities":' capabilities ...
                ',"clientInfo":{"name":"test","version":"1.0"}}}'];
            response = test.post(body, cell(0,2));
        end

        function response = ping(test, session)
            import prodserver.mcp.protocol.v20250618.Constants
            response = test.post('{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}', ...
                {Constants.SessionId, char(session)});
        end

        function response = post(test, body, headers)
            import prodserver.mcp.MCPConstants
            req = test.baseRequest;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}; ...
                headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Method = "POST";
            req.Path = "/prime/mcp";
            req.Body = unicode2native(body, "UTF-8");
            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);
        end

        function response = deleteSession(test, session)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants
            req = test.baseRequest;
            req.Method = "DELETE";
            req.Path = "/prime/mcp";
            req.Headers = [req.Headers; ...
                {Constants.SessionId, char(session)}; ...
                {MCPConstants.ContentLength, '0'}];
            response = prodserver.mcp.internal.mcpHandler(req);
        end

        function session = sessionHeader(~, response)
        % The response's Mcp-Session-Id, or "" if it has none.
            import prodserver.mcp.protocol.v20250618.Constants
            session = string(prodserver.mcp.internal.getHeaderValue( ...
                Constants.SessionId, response.Headers));
            if isempty(session)
                session = "";
            end
        end

    end
end
