classdef tSignatureApp < matlab.unittest.TestCase
% On a server built with an MCP App, /signature describes uri2json only to
% a client whose session declared MCP Apps support, as tools/list does.
% A request with no session, or another kind, gets the other signatures.

% Copyright 2026 The MathWorks, Inc.

    properties
        folder
    end

    methods (TestClassSetup)
        function initPath(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
        end
    end

    methods (TestMethodSetup)
        function buildApp(test)
        % The definitions build writes for toyToolOne with an app.
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.folder = tFolder.Folder;
            app = fullfile(test.folder, "view.html");
            writelines("<html><body>view</body></html>", app);
            prodserver.mcp.build("toyToolOne", folder=test.folder, ...
                stop="Definition", app=app);
            test.applyFixture(PathFixture(test.folder));

            % The definitions are cached; clear them now and afterwards.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function tHiddenWithoutSession(test)
            names = test.signatureNames(string.empty);
            test.verifyFalse(ismember("uri2json", names), strjoin(names, ", "));
            test.verifyTrue(ismember("toyToolOne", names), strjoin(names, ", "));
        end

        function tHiddenFromOtherClients(test)
            token = prodserver.mcp.test.sessionToken();
            names = test.signatureNames(token);
            test.verifyFalse(ismember("uri2json", names), strjoin(names, ", "));
            test.verifyTrue(ismember("toyToolOne", names), strjoin(names, ", "));
        end

        function tListedForAppHosts(test)
            token = prodserver.mcp.test.sessionToken(test.appCapabilities());
            names = test.signatureNames(token);
            test.verifyTrue(ismember("uri2json", names), strjoin(names, ", "));
        end

        function tNamedRequestNotFound(test)
        % Asked for by name, it's a signature this client can't have; an
        % app host gets it, and anyone gets another tool's, so the 404 is
        % the filter's, not a malformed request's.
            appSession = prodserver.mcp.test.sessionToken(test.appCapabilities());
            cases = {"uri2json", string.empty, 404; ...
                "uri2json", appSession, 200; ...
                "toyToolOne", string.empty, 200};
            for n = 1:size(cases, 1)
                response = test.named(cases{n,1}, cases{n,2});
                test.verifyEqual(response.HttpCode, cases{n,3}, ...
                    cases{n,1} + ", session: " + ~isempty(cases{n,2}));
            end
        end

    end

    methods (Access = private)

        function req = request(~, token)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants
            req = struct('ApiVersion', [1 0 0], 'Method', 'GET', ...
                'Headers', {{'Server', 'MATLAB Production Server'; ...
                    MCPConstants.ContentType, 'text/plain'}});
            if ~isempty(token)
                req.Headers = [req.Headers; {Constants.SessionId, token}];
            end
        end

        function response = named(test, name, token)
        % POST /signature asking for the signature of NAME.
            import prodserver.mcp.MCPConstants
            req = test.request(token);
            req.Method = 'POST';
            req.Body.Data = name;
            req.Headers = [req.Headers; {MCPConstants.ContentLength, strlength(name)}];
            response = prodserver.mcp.internal.signatureHandler(req);
        end

        function names = signatureNames(test, token)
            import prodserver.mcp.MCPConstants
            req = test.request(token);
            req.Headers = [req.Headers; {MCPConstants.ContentLength, 0}];
            response = prodserver.mcp.internal.signatureHandler(req);
            test.assertEqual(response.HttpCode, 200);
            names = string(fieldnames(prodserver.mcp.internal.decodeBody(response)))';
        end

        function declared = appCapabilities(~)
            declared = jsondecode(['{"extensions":{"' ...
                char(prodserver.mcp.MCPConstants.UIExtension_JSON) '":{}}}']);
        end

    end
end
