classdef tValidateHeaders < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.validateHeaders.
%
% Headers are enforced strictly as of Phase 3 (D40): absent is a failure,
% not a pass. Every absence and every mismatch is -32020 over HTTP 400, so
% these tests assert the identifier and leave the status to tToolsCallErrors
% and the integration conformance suite, which see a real response.
%
% The mismatch tests deliberately supply every OTHER required header. Before
% Phase 3 they supplied only the header they mismatched on, which meant they
% passed whether or not the mismatch was what rejected them -- a missing
% header would have raised the same identifier for a different reason. A
% test that cannot distinguish the two is not coverage of either.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        C
        MetaField
        version
    end

    methods (TestMethodSetup)
        function loadConstants(test)
            test.C = prodserver.mcp.protocol.v20260728.Constants;
            test.MetaField = prodserver.mcp.MCPConstants.MetaField;
            test.version = test.C.Version;
        end
    end

    methods (Access = private)

        function request = fullSet(test, method, name)
        % Every header this revision requires, correct for METHOD.
            rows = {
                prodserver.mcp.MCPConstants.ProtocolVersion, char(test.version)
                test.C.McpMethod, char(method)
                };
            if nargin >= 3
                rows = [rows; {test.C.McpName, char(name)}];
            end
            request = struct('Headers', {rows});
        end

        function verifyMismatch(test, request, jrpc, context)
            test.verifyError( ...
                @() prodserver.mcp.protocol.v20260728.validateHeaders( ...
                    request, jrpc, test.version), ...
                'prodserver:mcp:HeaderMismatch', context);
        end

        function verifyAccepted(test, request, jrpc, context)
            try
                prodserver.mcp.protocol.v20260728.validateHeaders( ...
                    request, jrpc, test.version);
            catch me
                test.verifyFail(context + ": unexpected " + me.identifier + ...
                    " -- " + me.message);
            end
        end

    end

    methods (Test)

        % --- the happy paths ------------------------------------------------

        function tValidHeadersNoError(test)
            jrpc = struct('method', 'tools/list', 'params', struct());
            test.verifyAccepted(test.fullSet('tools/list'), jrpc, ...
                "version + method, on a method needing no name");
        end

        function tValidHeadersWithNameNoError(test)
            jrpc = struct('method', 'tools/call', ...
                'params', struct('name', 'myTool'));
            test.verifyAccepted(test.fullSet('tools/call', 'myTool'), jrpc, ...
                "all three headers on a name-requiring method");
        end

        function tMcpNameNotRequiredOnOtherMethods(test)
        % The complement of the required-name tests, and what stops strict
        % enforcement from over-rejecting: tools/list names nothing, so
        % omitting Mcp-Name must be accepted rather than merely tolerated.
            for mth = ["tools/list", "resources/list", ...
                       "resources/templates/list", "server/discover"]
                jrpc = struct('method', char(mth), 'params', struct());
                test.verifyAccepted(test.fullSet(char(mth)), jrpc, ...
                    "Mcp-Name must not be required for " + mth);
            end
        end

        function tMcpNameUsesUriForResourcesRead(test)
            jrpc = struct('method', 'resources/read', ...
                'params', struct('uri', 'res://data'));
            test.verifyAccepted( ...
                test.fullSet('resources/read', 'res://data'), jrpc, ...
                "resources/read mirrors params.uri");
        end

        % --- absence is now a failure (inverted at Phase 3, D40) -----------

        function tMissingAllHeadersThrows(test)
        % Was tMissingHeadersNoError, which codified the pre-D40 decision
        % that a header-less request passes. Inverted deliberately: the spec
        % lists a missing required header as an explicit -32020 trigger, and
        % reaching this function means the request was already attributed to
        % this revision, which is the condition that makes the MUST bind.
            jrpc = struct('method', 'tools/list', 'params', struct());
            test.verifyMismatch(struct('Headers', {cell(0,2)}), jrpc, ...
                "a request carrying no headers at all");
        end

        function tNoHeadersFieldThrows(test)
        % The same, for a request whose Headers is an empty 0x0 cell rather
        % than an empty Nx2 one. getHeaderValue rejects anything that is not
        % two columns wide, so without the guard at the top of
        % validateHeaders this raised an error about name-value pairs --
        % mapped to -32603/500, reporting a client's omission as a server
        % fault, which is the whole G3 failure mode.
            jrpc = struct('method', 'tools/list', 'params', struct());
            test.verifyMismatch(struct('Headers', {{}}), jrpc, ...
                "a request whose Headers cell is empty");
        end

        function tMissingProtocolVersionThrows(test)
            jrpc = struct('method', 'tools/list', 'params', struct());
            request = struct('Headers', ...
                {{test.C.McpMethod, 'tools/list'}});
            test.verifyMismatch(request, jrpc, ...
                "MCP-Protocol-Version absent, every other header correct");
        end

        function tMissingMcpMethodThrows(test)
            jrpc = struct('method', 'tools/list', 'params', struct());
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, ...
                  char(test.version)}});
            test.verifyMismatch(request, jrpc, ...
                "Mcp-Method absent, every other header correct");
        end

        function tMissingMcpNameOnNameMethodThrows(test)
            jrpc = struct('method', 'tools/call', ...
                'params', struct('name', 'myTool'));
            test.verifyMismatch(test.fullSet('tools/call'), jrpc, ...
                "Mcp-Name absent on tools/call, every other header correct");
        end

        % --- mismatches, with the other headers supplied correctly ---------

        function tMismatchedProtocolVersionThrows(test)
        % Tightened: version header wrong, Mcp-Method correct. Before
        % Phase 3 this request carried no Mcp-Method either, so it would
        % have been rejected even by an implementation that ignored the
        % version entirely.
            jrpc = struct('method', 'tools/list', 'params', struct());
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, '9999-01-01'; ...
                  test.C.McpMethod, 'tools/list'}});
            test.verifyMismatch(request, jrpc, ...
                "version header contradicts _meta");
        end

        function tMismatchedMcpMethodThrows(test)
        % Tightened the same way: version header correct and present, so
        % only the method disagreement can be what rejects this.
            jrpc = struct('method', 'tools/list', 'params', struct());
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, ...
                  char(test.version); ...
                  test.C.McpMethod, 'resources/list'}});
            test.verifyMismatch(request, jrpc, ...
                "Mcp-Method contradicts body method");
        end

        function tMismatchedMcpNameThrows(test)
            jrpc = struct('method', 'tools/call', ...
                'params', struct('name', 'myTool'));
            test.verifyMismatch( ...
                test.fullSet('tools/call', 'wrongTool'), jrpc, ...
                "Mcp-Name contradicts params.name");
        end

        % --- header present, body field absent -----------------------------

        function tMcpNameWithoutBodyNameThrows(test)
        % The hole Phase 3 closed. The comparison used to be guarded by
        % ~isempty(bodyName), so a tools/call with no params.name accepted
        % ANY Mcp-Name value. The body is malformed either way and
        % tools/call would have rejected it downstream -- but with -32602
        % over HTTP 200, not the -32020/400 a bad required header mandates.
            jrpc = struct('method', 'tools/call', 'params', struct());
            test.verifyMismatch( ...
                test.fullSet('tools/call', 'anythingAtAll'), jrpc, ...
                "tools/call with Mcp-Name but no params.name");
        end

        function tMcpNameWithoutBodyUriThrows(test)
            jrpc = struct('method', 'resources/read', 'params', struct());
            test.verifyMismatch( ...
                test.fullSet('resources/read', 'res://anything'), jrpc, ...
                "resources/read with Mcp-Name but no params.uri");
        end

        function tMcpNameWithoutParamsAtAllThrows(test)
            jrpc = struct('method', 'tools/call');
            test.verifyMismatch( ...
                test.fullSet('tools/call', 'anythingAtAll'), jrpc, ...
                "tools/call with Mcp-Name but no params member");
        end

        % --- the Base64 sentinel, from the server's side --------------------

        function tEncodedMcpNameIsDecodedBeforeComparing(test)
        % A non-ASCII resource URI cannot travel as a plain header value, so
        % the client sends it wrapped. Comparing the wrapper to the body
        % reports a mismatch that is not one; the server MUST decode first.
            uri = "res://caf" + string(char(233)) + "/data";
            encoded = prodserver.mcp.protocol.v20260728.encodeHeaderValue(uri);
            test.assertNotEqual(encoded, uri, ...
                "this URI must actually need encoding, or the test is vacuous");

            jrpc = struct('method', 'resources/read', ...
                'params', struct('uri', uri));
            test.verifyAccepted( ...
                test.fullSet('resources/read', char(encoded)), jrpc, ...
                "an encoded Mcp-Name matching the body");
        end

        function tEncodedMcpNameStillCatchesAMismatch(test)
        % Decoding must not become a way to accept anything: a correctly
        % encoded header carrying the WRONG value is still -32020.
            sent = prodserver.mcp.protocol.v20260728.encodeHeaderValue( ...
                "res://caf" + string(char(233)) + "/other");
            jrpc = struct('method', 'resources/read', 'params', ...
                struct('uri', "res://caf" + string(char(233)) + "/data"));
            test.verifyMismatch( ...
                test.fullSet('resources/read', char(sent)), jrpc, ...
                "an encoded Mcp-Name that decodes to the wrong value");
        end

        function tResourceNamedLikeASentinelRoundTrips(test)
        % The ambiguity the encode-a-literal-sentinel rule exists for: a
        % resource whose name IS "=?base64?Zm9v?=" must not be mistaken for
        % an encoding of "foo".
            name = test.C.HeaderSentinelPrefix + "Zm9v" + ...
                test.C.HeaderSentinelSuffix;
            encoded = prodserver.mcp.protocol.v20260728.encodeHeaderValue(name);
            jrpc = struct('method', 'tools/call', ...
                'params', struct('name', name));
            test.verifyAccepted( ...
                test.fullSet('tools/call', char(encoded)), jrpc, ...
                "a tool literally named like a sentinel");

            test.verifyError( ...
                @() prodserver.mcp.protocol.v20260728.validateHeaders( ...
                    test.fullSet('tools/call', char(name)), jrpc, ...
                    test.version), ...
                'prodserver:mcp:HeaderMismatch', ...
                "sent unencoded, it decodes to 'foo' and must not match");
        end

    end

end
