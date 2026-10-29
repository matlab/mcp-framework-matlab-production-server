classdef tAdapterErrorMapping < matlab.unittest.TestCase
% Error mapping that every protocol revision must agree on.
%
% Each revision's own suite holds the rows where the revisions DIFFER -- the
% ones that are the whole reason mapErrorCode is per-revision, such as
% ResourceNotFound (-32002 over 200 for 2025-06-18, -32602 for 2026-07-28) or
% MethodNotFound's status. Everything they agree on lived in both suites as
% byte-identical table rows, which is how an identifier gets added to one
% revision's mapper and quietly skipped in the other.
%
% Parameterized by version off the registry, so a new adapter is held to these
% invariants from the moment it exists, with no test edit at all.
%
% What belongs here is an answer that is the same for every revision because
% of something revision-independent -- the framework's own error vocabulary,
% or JSON-RPC 2.0 itself -- not merely an answer that happens to coincide
% today. If a future revision has a genuine reason to diverge on one of these,
% the fix is to move that row into that revision's own suite and say why, not
% to weaken the assertion here.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        Registry = prodserver.mcp.protocol.ProtocolRegistry.instance()
    end

    properties (TestParameter)
        % Filled in by registeredVersions below. Declared without a value: a
        % TestParameterDefinition method must match a parameterization
        % property declared in the same class.
        version
    end

    methods (Static, TestParameterDefinition)
        function version = registeredVersions()
            vs = prodserver.mcp.protocol.ProtocolRegistry.instance( ...
                ).supportedVersions();
            version = struct();
            for v = reshape(vs, 1, [])
                version.(matlab.lang.makeValidName("v" + v)) = v;
            end
        end
    end

    methods (Access = private)

        function [result, httpCode, httpMsg] = mapped(test, version, identifier)
        % Raise IDENTIFIER and map it through VERSION's adapter.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'test');
            adapter = test.Registry.lookup(version);
            try
                error(identifier, 'synthetic');
            catch me
                [result, httpCode, httpMsg] = adapter.formatError(me, jrpc);
            end
        end

    end

    methods (Test)

        function tClientMistakeIsNeverInternalError(test, version)
            % protocol.clientMistakes is the framework's own vocabulary, not
            % any spec's: these identifiers mean the server worked and the
            % request was wrong. Both specs' worked example for that case is
            % {"code": -32602, ...} over a successful transport, so reporting
            % one as -32603/500 contradicts the published shape -- in any
            % revision.
            %
            % The list is iterated rather than restated, so adding a seventh
            % identifier to clientMistakes covers it on every revision at once.
            import prodserver.mcp.MCPConstants

            ids = prodserver.mcp.protocol.clientMistakes();
            test.assertNotEmpty(ids);
            for k = 1:numel(ids)
                [result, httpCode] = test.mapped(version, ids(k));
                test.verifyEqual(result.error.code, ...
                    MCPConstants.ErrorInvalidParams, ...
                    "code for " + ids(k) + " under " + version);
                test.verifyEqual(httpCode, 200, ...
                    "status for " + ids(k) + " under " + version + ...
                    ": a caller's mistake is not a transport failure");
            end
        end

        function tUnmappedIdentifierIsInternalError(test, version)
            % The default arm. An identifier no mapper recognizes is by
            % definition not a diagnosis anyone made, so it is the one case
            % that genuinely is a server fault: -32603 over 500.
            [result, httpCode, httpMsg] = ...
                test.mapped(version, 'some:deliberately:UnmappedError');
            test.verifyEqual(result.error.code, ...
                prodserver.mcp.MCPConstants.ErrorInternalError);
            test.verifyEqual(httpCode, 500);
            test.verifyEqual(httpMsg, 'Internal Server Error');
        end

        function tErrorResponseShape(test, version)
            % JSON-RPC 2.0: a response carries error XOR result, and the
            % error message must survive rather than be replaced by a generic
            % one. Nothing revision-specific about either.
            [result, ~, ~] = test.mapped(version, 'prodserver:mcp:ToolUnavailable');
            test.assertTrue(isfield(result, 'error'));
            test.verifyFalse(isfield(result, 'result'), ...
                "A response must not carry both error and result");
            test.verifyTrue(contains(string(result.error.message), "synthetic"), ...
                "The original message must survive mapping");
            test.verifyEqual(result.id, 1);
        end

        function tErrorEchoesNullIdWhenUnknown(test, version)
            % JSON-RPC 2.0 requires an id member on every response; when the
            % request id could not be read it is null, not absent. formatError
            % is handed [] for the body in exactly that case.
            adapter = test.Registry.lookup(version);
            try
                error('prodserver:mcp:MethodNotFound', 'no such method');
            catch me
                result = adapter.formatError(me, []);
            end
            test.assertTrue(isfield(result, 'id'));
            test.verifyEqual(result.id, NaN);
            json = prodserver.mcp.jsonrpc.encodeMessage(result);
            test.verifyTrue(contains(json, '"id":null'), ...
                "Unknown id must serialize as null under " + version + ...
                ", got: " + json);
        end

        function tMethodNotFoundCodeIsSharedButStatusIsNot(test)
            % The counter-example to everything above, and the reason the
            % status cannot be hoisted into a shared mapper: one identifier,
            % one JSON-RPC code, and a status each revision decides for
            % itself. 2025-06-18 carries the error in the body over a
            % successful transport; 2026-07-28 mandates 404.
            %
            % Deliberately not parameterized -- the assertion is about the
            % revisions disagreeing, which no single-revision test can
            % express. Stated as "not all the same" rather than as two
            % literals: that is the claim the shared mapper would violate,
            % and it survives a third revision whichever status it picks.
            import prodserver.mcp.MCPConstants

            versions = test.Registry.versionsNewestFirst();
            statuses = zeros(1, numel(versions));
            for k = 1:numel(versions)
                [result, statuses(k)] = test.mapped(versions(k), ...
                    'prodserver:mcp:MethodNotFound');
                test.verifyEqual(result.error.code, ...
                    MCPConstants.ErrorMethodNotFound, ...
                    "The JSON-RPC code is shared: " + versions(k));
            end

            test.verifyGreaterThan(numel(unique(statuses)), 1, ...
                "The mandated statuses differ per revision, so a shared " + ...
                "status mapper cannot be correct. Got: " + ...
                strjoin(string(statuses), ", "));
        end

    end

end
