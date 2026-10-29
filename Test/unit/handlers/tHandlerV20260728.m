classdef tHandlerV20260728 < matlab.unittest.TestCase
% End-to-end mcpHandler behaviour that only the 2026-07-28 revision defines:
% the server/discover method that replaced the handshake, and the two
% request-level validations that a per-request _meta envelope makes possible
% (a header contradicting the body, and a _meta missing a required member).
%
% These were previously methods of tmcpHandler, which parameterizes every test
% by protocol. There each one immediately filtered away every parameter but
% 2026-07-28 -- the parameter could not be anything else, because the
% behaviour under test does not exist in the other revision. A filtered case
% is not a passing case, and a suite that reports incompletes as a matter of
% routine trains you to stop reading them.
%
% So they live here instead, in a suite named for the revision that defines
% them and parameterized by nothing. tmcpHandler keeps the tests that every
% revision genuinely has to pass, and now passes all of them for real.
%
% Built by hand rather than on MCPHandlerBase for the same reason
% tVersionResolution is: the envelope is part of what is being asserted, and
% applyProtocol would overwrite it.

% Copyright 2026 The MathWorks, Inc.

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

    methods (Access = private)

        function decoded = post(test, body, headers)
        %post POST a body with exactly the given extra headers, and no more.
            arguments
                test
                body
                headers = cell(0,2)
            end
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
            decoded = prodserver.mcp.internal.decodeBody(response);
        end

        function body = metaBody(~, id, method, members)
        %metaBody A request whose params._meta carries the given members.
        %   MEMBERS is the raw JSON for the inside of _meta, so a test can
        %   omit a required member deliberately.
            body = sprintf(['{ "jsonrpc": "2.0", "id": %d, "method": "%s", ' ...
                '"params": { "_meta": { %s } } }'], id, method, members);
        end

        function body = wellFormedBody(test, id, method)
        %wellFormedBody A request whose _meta declares everything required.
            C = prodserver.mcp.protocol.v20260728.Constants;
            body = test.metaBody(id, method, sprintf( ...
                '"%s": "%s", "%s": {}', ...
                C.MetaProtocolVersion_JSON, C.Version, ...
                C.MetaCapabilities_JSON));
        end

        function rows = requiredHeaders(~, method)
        %requiredHeaders The headers this revision requires for METHOD.
        %   Written out rather than taken from protocolHeaderRows, because
        %   post's whole purpose is to send exactly the headers a test names
        %   and the header set is part of what several tests assert. None of
        %   the methods used here names a thing, so Mcp-Name never applies.
            C = prodserver.mcp.protocol.v20260728.Constants;
            rows = {
                prodserver.mcp.MCPConstants.ProtocolVersion, char(C.Version)
                C.McpMethod, char(method)
                };
        end

    end

    methods (Test)

        function serverDiscoverIsServed(test)
        % server/discover through the full handler, not just the adapter.
        % 2026-07-28 removed `initialize`, so this is the only way a client
        % learns what the server can do, and the result is tagged complete
        % because this revision allows a partial answer and this one is not.
            import prodserver.mcp.internal.hasField

            decoded = test.post(test.wellFormedBody(1, "server/discover"), ...
                test.requiredHeaders("server/discover"));

            test.verifyEqual(decoded.id, 1);
            test.verifyFalse(hasField(decoded, 'error'), ...
                "server/discover should succeed, not return an error");
            test.assertTrue(hasField(decoded, 'result'));
            test.verifyEqual(string(decoded.result.resultType), "complete");
        end

        function serverDiscoverCarriesCacheHints(test)
        % DiscoverResult extends CacheableResult, so both fields are
        % required. Checked after the full handler, encoding included,
        % because a field lost on the way to JSON is as missing as one
        % never set.
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.MCPConstants

            decoded = test.post(test.wellFormedBody(2, "server/discover"), ...
                test.requiredHeaders("server/discover"));

            test.assertTrue(hasField(decoded, 'result'));
            test.verifyEqual(decoded.result.ttlMs, ...
                MCPConstants.DefinitionCacheTtlMs);
            test.verifyEqual(string(decoded.result.cacheScope), ...
                MCPConstants.DefinitionCacheScope);
        end

        function headerMethodContradictingBodyIs32020(test)
        % Mcp-Method restates the body's method in a header so a proxy can
        % route without parsing the body. The two disagreeing is the error
        % this revision mints -32020 for: serving it would mean the proxy and
        % the server acted on different requests.
        %
        % The version header is supplied, and correct. Without it this test
        % would pass against an implementation that ignored Mcp-Method
        % entirely, since a missing required header raises the same
        % identifier -- and as of Phase 3 that is no longer hypothetical.
            import prodserver.mcp.internal.hasField
            C = prodserver.mcp.protocol.v20260728.Constants;

            decoded = test.post(test.wellFormedBody(7, "tools/list"), ...
                {prodserver.mcp.MCPConstants.ProtocolVersion, ...
                    char(C.Version); ...
                 C.McpMethod, 'tools/call'});

            test.assertTrue(hasField(decoded, 'error.code'));
            test.verifyEqual(decoded.error.code, C.ErrorHeaderMismatch);
        end

        function metaWithoutCapabilitiesIsInvalidParams(test)
        % A _meta that declares a protocol version is enough for this
        % revision to claim the request, which is what makes the missing
        % clientCapabilities a -32602 from this revision's own mapper rather
        % than an unattributable request. The distinction matters: both are
        % 400, but only one of them tells the client which member to add.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField
            C = prodserver.mcp.protocol.v20260728.Constants;

            % Every required header present and correct, so the only fault
            % in this request is the one being asserted. validateMeta runs
            % ahead of validateHeaders today, which would make an incomplete
            % header set harmless here -- but that is an ordering detail,
            % not something this test should depend on.
            body = test.metaBody(8, "tools/list", sprintf('"%s": "%s"', ...
                C.MetaProtocolVersion_JSON, C.Version));
            decoded = test.post(body, test.requiredHeaders("tools/list"));

            test.assertTrue(hasField(decoded, 'error.code'));
            test.verifyEqual(decoded.error.code, ...
                MCPConstants.ErrorInvalidParams);
        end

    end

end
