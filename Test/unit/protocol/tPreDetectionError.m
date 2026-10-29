classdef tPreDetectionError < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.Adapter.preDetectionError -- the hook that
% lets handler.internal reach a revision's error codes without naming the
% revision.
%
% Two failures can be raised after a request has been attributed to a
% revision but before that revision has accepted the version the request
% states: HeaderMismatch and UnsupportedProtocolVersion, both from
% ProtocolRegistry.resolve. Their correct code depends on which revision the
% request declared, so mapPreDetectionError asks the attributed adapter
% rather than reaching into one revision's Constants.
%
% The selector is the adapter ATTRIBUTION chose, deliberately not the newest
% registered adapter. tV20250618RequestIsAnsweredByItsOwnRevision is the
% guard on that distinction: it exercises a request attributed to 2025-06-18,
% which a newest-first selector would hand to 2026-07-28 instead. Today both
% revisions happen to answer -32022, so that test cannot fail on the code
% alone -- it asserts which adapter was consulted.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        Registry = prodserver.mcp.protocol.ProtocolRegistry.instance()
    end

    methods (Access = private)

        function answer = ask(test, version, identifier, jrpc, request)
            arguments
                test
                version
                identifier
                jrpc = []
                request = []
            end
            adapter = test.Registry.lookup(version);
            answer = adapter.preDetectionError(identifier, jrpc, request);
        end

        function response = post(~, body, headers)
            req = struct('ApiVersion', [1 0 0], 'Headers', {headers});
            req.Method = "POST";
            req.Path = "/prime/mcp";
            req.Body = unicode2native(body, "UTF-8");
            response = prodserver.mcp.internal.mcpHandler(req);
        end

    end

    methods (Test)

        function tEveryAdapterAcceptsTheHook(test)
            % The hook is defaulted on the base class, so a revision that
            % declares no opinion still answers the call rather than erroring
            % on an undefined method. This is what lets a new adapter be
            % added without touching handler.internal at all.
            for version = test.Registry.versionsNewestFirst()
                answer = test.ask(version, "some:unrelated:Error");
                test.verifyEmpty(answer, ...
                    version + " must return [] for an identifier it does " + ...
                    "not claim, so the neutral arms stand");
            end
        end

        function tV20260728AnswersHeaderMismatch(test)
            C = prodserver.mcp.protocol.v20260728.Constants;
            answer = test.ask("2026-07-28", "prodserver:mcp:HeaderMismatch");
            test.assertNotEmpty(answer);
            test.verifyEqual(answer.code, C.ErrorHeaderMismatch);
            test.verifyEqual(answer.httpCode, 400);
        end

        function tHeaderMismatchIsNotClaimedByTheSessionRevision(test)
            % HeaderMismatch compares a header against params._meta, which a
            % request attributed to 2025-06-18 does not carry. It must decline
            % rather than invent an answer.
            test.verifyEmpty( ...
                test.ask("2025-06-18", "prodserver:mcp:HeaderMismatch"));
        end

        function tBothRevisionsCarryTheSupportedList(test)
            % The `supported` payload is what lets a caller recover, so every
            % revision that answers UnsupportedProtocolVersion must include
            % it -- and it must come from the registry, not a literal.
            expected = test.Registry.supportedVersions();
            for version = test.Registry.versionsNewestFirst()
                answer = test.ask(version, ...
                    "prodserver:mcp:UnsupportedProtocolVersion");
                test.assertNotEmpty(answer, ...
                    version + " must answer UnsupportedProtocolVersion");
                test.verifyEqual(answer.httpCode, 400);
                test.assertTrue(isfield(answer.data, 'supported'));
                test.verifyEqual(string(answer.data.supported(:))', ...
                    reshape(expected, 1, []));
            end
        end

        function tV20250618RequestIsAnsweredByItsOwnRevision(test)
        % The selector guard. An `initialize` body attributes to 2025-06-18 by
        % shape; resolve then looks up an unsupported MCP-Protocol-Version
        % header and raises. The answer must come from the 2025-06-18 hook,
        % which is the adapter attribution chose -- a newest-first selector
        % would consult 2026-07-28 for this request.
            response = test.post( ...
                '{"jsonrpc":"2.0","id":7,"method":"initialize","params":{}}', ...
                {'Content-Type','application/json'; ...
                 'MCP-Protocol-Version','1999-01-01'});

            test.verifyEqual(response.HttpCode, 400);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(prodserver.mcp.internal.hasField(decoded, ...
                'error.data.requested'));
            test.verifyEqual(string(decoded.error.data.requested), "1999-01-01");

            % Proves which adapter was asked: 2025-06-18 is the only one whose
            % hook declines HeaderMismatch, and the only one reachable with no
            % params._meta in the body at all.
            expected = test.ask("2025-06-18", ...
                "prodserver:mcp:UnsupportedProtocolVersion");
            test.verifyEqual(decoded.error.code, expected.code);
        end

        function tUnattributedFailuresStayNeutral(test)
            % Nothing was attributed, so there is no hook to ask and the
            % neutral arms must answer. If the hook ever became mandatory
            % these would turn into -32603/500.
            C = prodserver.mcp.MCPConstants;
            % decodeBody rejects any JSON array on the raw text, before
            % attribution, so a single-element batch would do as well (see
            % tmcpHandler/singleElementBatchIsInvalidRequest).
            cases = { ...
                '{not json',                                     C.ErrorParseError
                ['[{"jsonrpc":"2.0","id":1,"method":"ping"},' ...
                 '{"jsonrpc":"2.0","id":2,"method":"ping"}]'],    C.ErrorInvalidRequest
                '{"jsonrpc":"2.0","id":8,"method":"tools/list"}'  C.ErrorInvalidParams
                };
            for k = 1:size(cases, 1)
                response = test.post(cases{k,1}, ...
                    {'Content-Type','application/json'});
                decoded = prodserver.mcp.internal.decodeBody(response);
                test.verifyEqual(response.HttpCode, 400);
                test.verifyEqual(decoded.error.code, cases{k,2}, ...
                    "Neutral arm changed for body: " + cases{k,1});
            end
        end

    end

end
