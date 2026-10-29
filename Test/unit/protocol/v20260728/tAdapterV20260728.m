classdef tAdapterV20260728 < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.Adapter.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        adapter
    end

    methods (TestMethodSetup)
        function createAdapter(test)
            test.adapter = prodserver.mcp.protocol.v20260728.Adapter();
        end
    end

    methods (Access = private)

        function jrpc = buildJrpc(~, method, id)
            C = prodserver.mcp.protocol.v20260728.Constants;
            MetaField = prodserver.mcp.MCPConstants.MetaField;
            jrpc.jsonrpc = "2.0";
            if nargin >= 3
                jrpc.id = id;
            end
            jrpc.method = method;
            jrpc.params.(MetaField).(C.MetaProtocolVersion_Field) = C.Version;
            jrpc.params.(MetaField).(C.MetaCapabilities_Field) = struct();
        end

        function request = buildRequest(~, method)
        %buildRequest A request carrying this revision's required headers.
        %   METHOD is optional, because handleDelete and responseHeaders
        %   never look at Mcp-Method and a caller testing those should not
        %   have to name a method it is not sending. handlePost does look:
        %   validateHeaders requires the header as of Phase 3, so the two
        %   handlePost callers below must supply it or earn a -32020 on a
        %   request that is otherwise correct.
            C = prodserver.mcp.protocol.v20260728.Constants;
            rows = {prodserver.mcp.MCPConstants.ProtocolVersion, ...
                char(C.Version)};
            if nargin >= 2
                rows = [rows; {C.McpMethod, char(method)}];
            end
            request = struct('Headers', {rows});
        end

    end

    methods (Test)

        function tMatchesMetaField(test)
            request = struct('Headers', {{}});
            jrpc = test.buildJrpc("tools/list", 1);
            test.verifyTrue(test.adapter.matches(request, jrpc));
        end

        function tDoesNotMatchWithoutMeta(test)
            request = struct('Headers', {{}});
            jrpc = struct('method', 'tools/list');
            test.verifyFalse(test.adapter.matches(request, jrpc));
        end

        function tMatchesAnyPerRequestField(test)
        % Any one per-request field is the marker, so a request that omits
        % protocolVersion still reaches this adapter's MissingProtocolVersion.
            C = prodserver.mcp.protocol.v20260728.Constants;
            MetaField = prodserver.mcp.MCPConstants.MetaField;
            request = struct('Headers', {{}});
            for f = [C.MetaProtocolVersion_Field, C.MetaCapabilities_Field, ...
                    C.MetaCapabilitiesAlt_Field, C.MetaClientInfo_Field, ...
                    C.MetaLogLevel_Field]
                jrpc = struct('method', 'tools/list');
                jrpc.params.(MetaField).(f) = "x";
                test.verifyTrue(test.adapter.matches(request, jrpc), f);
            end
        end

        function tDoesNotMatchLegacyMeta(test)
        % _meta keys reserved in both eras are not per-request fields.
            MetaField = prodserver.mcp.MCPConstants.MetaField;
            request = struct('Headers', {{}});
            for f = ["progressToken", "traceparent"]
                jrpc = struct('method', 'tools/list');
                jrpc.params.(MetaField).(f) = "x";
                test.verifyFalse(test.adapter.matches(request, jrpc), f);
            end
        end

        function tDoesNotMatchNonStructMeta(test)
            MetaField = prodserver.mcp.MCPConstants.MetaField;
            request = struct('Headers', {{}});
            jrpc = struct('method', 'tools/list');
            jrpc.params.(MetaField) = [];
            test.verifyFalse(test.adapter.matches(request, jrpc));
        end

        function tDoesNotMatchEmpty(test)
            request = struct('Headers', {{}});
            test.verifyFalse(test.adapter.matches(request, []));
        end

        function tHandlePostDiscover(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture( ...
                fileparts(fileparts(fileparts(fileparts( ...
                mfilename("fullpath")))))));

            request = test.buildRequest("server/discover");
            jrpc = test.buildJrpc("server/discover", 1);

            [result, httpCode, ~, ~] = test.adapter.handlePost(request, jrpc);
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(result.id, 1);
            test.verifyTrue(isfield(result.result, 'supportedVersions'));
            test.verifyTrue(isfield(result.result, 'capabilities'));
            test.verifyTrue(isfield(result.result, 'instructions'));
        end

        function tHandleDeleteReturns405(test)
            request = test.buildRequest();
            [result, httpCode, httpMsg, ~] = test.adapter.handleDelete(request);
            test.verifyEqual(httpCode, 405);
            test.verifyEqual(httpMsg, 'Method Not Allowed');
            test.verifyEmpty(result);
        end

        % Six former tests stood here, each raising one identifier and
        % restating a single row of the table below: HeaderMismatch's code and
        % again its 400, MissingMeta as -32602, an unmapped identifier as
        % -32603/500, MethodNotFound as 404, and ResourceNotFound as -32602.
        % The rows remain; the singletons are gone, along with their
        % byte-identical twins in the 2025-06-18 suite, which are now in
        % tAdapterErrorMapping and are checked against every registered
        % revision instead of two hand-maintained copies.

        function tErrorTableCodeAndStatus(test)
            % The rows of v20260728.mapErrorCode that are specific to THIS
            % revision, asserting the code AND the status together. Asserting
            % only the code is what let the original defect through: -32602 is
            % deliberately overloaded, so the code alone cannot distinguish the
            % missing-_meta family (MUST be 400) from an unknown tool or bad
            % arguments (spec-silent and legitimately 200). A mapper that
            % switched on the numeric code instead of the identifier would pass
            % a code-only suite while trading one non-conformance for three.
            %
            % That overload is also why this table keeps the ResourceNotFound
            % row even though the code matches the shared answer: the status is
            % 200 while its missing-_meta neighbours on the same code are 400,
            % and the pair of rows is the assertion.
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            % {identifier, expected code, expected status}
            rows = {
                'prodserver:mcp:MethodNotFound',  MCPConstants.ErrorMethodNotFound, 404
                'prodserver:mcp:HeaderMismatch',  C.ErrorHeaderMismatch,            400
                'prodserver:mcp:UnsupportedProtocolVersion', ...
                                                  C.ErrorUnsupportedVersion,        400
                'prodserver:mcp:MissingMeta',            MCPConstants.ErrorInvalidParams, 400
                'prodserver:mcp:MissingProtocolVersion', MCPConstants.ErrorInvalidParams, 400
                'prodserver:mcp:MissingCapabilities',    MCPConstants.ErrorInvalidParams, 400
                'prodserver:mcp:ResourceNotFound',       MCPConstants.ErrorInvalidParams, 200
                };

            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'test');
            for k = 1:size(rows,1)
                ident = rows{k,1};
                try
                    error(ident, 'synthetic');
                catch me
                    [result, httpCode] = test.adapter.formatError(me, jrpc);
                end
                test.verifyEqual(result.error.code, rows{k,2}, ...
                    "code for " + ident);
                test.verifyEqual(httpCode, rows{k,3}, ...
                    "status for " + ident);
            end
        end

        function tNeverEmitsResourceNotFoundCode(test)
            % 2026-07-28 MUST NOT emit -32002; it folded resource-not-found
            % into Invalid Params (changelog minor #6). This is a genuine
            % spec prohibition, unlike the house rule about -3202x codes
            % under 2025-06-18.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'test');
            try
                error('prodserver:mcp:ResourceNotFound', 'no resource');
            catch me
                result = test.adapter.formatError(me, jrpc);
            end
            test.verifyNotEqual(result.error.code, -32002);
        end

        function tUnsupportedVersionCarriesSupportedList(test)
            % schema.ts declares `supported` without `?`, so it is not
            % optional on an UnsupportedProtocolVersionError.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'test');
            try
                error('prodserver:mcp:UnsupportedProtocolVersion', 'nope');
            catch me
                result = test.adapter.formatError(me, jrpc);
            end
            test.assertTrue(isfield(result.error, 'data'), ...
                "An unsupported-version error must carry data");
            test.verifyTrue(isfield(result.error.data, 'supported'));
            test.verifyNotEmpty(result.error.data.supported);
        end

        function tResponseHeadersIncludesVersion(test)
            request = test.buildRequest();
            jrpc = struct();
            headers = test.adapter.responseHeaders(request, jrpc);
            test.verifyEqual(string(headers{1,1}), ...
                string(prodserver.mcp.MCPConstants.ProtocolVersion));
            test.verifyEqual(string(headers{1,2}), "2026-07-28");
        end

        function tPostEncodeReplacesMetaSubfields(test)
            C = prodserver.mcp.protocol.v20260728.Constants;
            json = '{"_meta":{"io_modelcontextprotocol_serverInfo":{"name":"test"}}}';
            result = test.adapter.postEncode(json);
            test.verifyTrue(contains(result, C.MetaServerInfo_JSON));
            test.verifyFalse(contains(result, C.MetaServerInfo_Field));
        end

        function tResultIncludesResultTypeAndServerInfo(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture( ...
                fileparts(fileparts(fileparts(fileparts( ...
                mfilename("fullpath")))))));

            request = test.buildRequest("server/discover");
            jrpc = test.buildJrpc("server/discover", 1);

            [result, ~, ~, ~] = test.adapter.handlePost(request, jrpc);

            C = prodserver.mcp.protocol.v20260728.Constants;
            MetaField = prodserver.mcp.MCPConstants.MetaField;

            test.verifyEqual(string(result.result.resultType), "complete");
            test.verifyTrue(isfield(result.result, MetaField));
            serverInfo = result.result.(MetaField).(C.MetaServerInfo_Field);
            test.verifyEqual(string(serverInfo.name), ...
                string(prodserver.mcp.MCPConstants.ServerName));
            test.verifyEqual(string(serverInfo.version), ...
                string(prodserver.mcp.MCPConstants.ServerVersion));
        end

        function tServerInfoTitleIsArchiveName(test)
            % As initialize's serverInfo has, under 2025-06-18.
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture( ...
                fileparts(fileparts(fileparts(fileparts( ...
                mfilename("fullpath")))))));
            request = test.buildRequest("server/discover");
            request.Path = "/myArchive/mcp";
            jrpc = test.buildJrpc("server/discover", 1);
            [result, ~, ~, ~] = test.adapter.handlePost(request, jrpc);
            C = prodserver.mcp.protocol.v20260728.Constants;
            serverInfo = result.result.(prodserver.mcp.MCPConstants.MetaField ...
                ).(C.MetaServerInfo_Field);
            test.verifyEqual(string(serverInfo.title), "myArchive");
        end

    end

end
