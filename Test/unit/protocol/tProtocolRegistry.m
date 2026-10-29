classdef tProtocolRegistry < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.ProtocolRegistry (discovery, detect, lookup).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tDiscoversV20250618Adapter(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            versions = reg.supportedVersions();
            test.verifyTrue(ismember("2025-06-18", versions));
        end

        function tEveryDiscoveredAdapterIsRegistered(test)
            % Discovery is by meta.package introspection: an adapter
            % registers itself by existing in the +protocol namespace. The
            % contract is therefore that the two agree -- every class
            % adapterClasses finds ends up answering for a version -- not that
            % there are two of them. Pinning the count made adding an adapter
            % fail a test that had no opinion about the new adapter at all,
            % which teaches you to edit the number and move on.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            versions = reg.supportedVersions();
            names = prodserver.mcp.protocol.ProtocolRegistry.adapterClasses();

            test.verifyNotEmpty(versions, ...
                "A server with no protocol adapters cannot serve anything");
            test.verifyNumElements(versions, numel(names), ...
                "Every discovered adapter class must register exactly one " + ...
                "version, and no version may appear without one");

            % And each registered version must hand back a live adapter that
            % agrees about its own version -- the keys cannot drift from the
            % objects they are stored under.
            for v = reshape(versions, 1, [])
                test.verifyEqual(string(reg.lookup(v).Version), v);
            end
        end

        function tDiscoversV20260728Adapter(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            versions = reg.supportedVersions();
            test.verifyTrue(ismember("2026-07-28", versions));
        end

        function tDetectInitializeMethod(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{}});
            jrpc = struct('method', 'initialize');
            adapter = reg.detect(request, jrpc);
            test.verifyEqual(adapter.Version, "2025-06-18");
        end

        function tDetectSessionHeader(test)
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{Constants.SessionId, 'abc-123'}});
            jrpc = struct('method', 'tools/call');
            adapter = reg.detect(request, jrpc);
            test.verifyEqual(adapter.Version, "2025-06-18");
        end

        function tDetectNoMatchThrows(test)
        % No _meta, no initialize, no session header: nothing in the request
        % says which protocol it speaks.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{}});
            jrpc = struct('method', 'tools/call');
            test.verifyError(@() reg.detect(request, jrpc), ...
                'prodserver:mcp:UnattributableRequest');
        end

        function tLookupExactVersion(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            adapter = reg.lookup("2025-06-18");
            test.verifyEqual(adapter.Version, "2025-06-18");
        end

        function tLookupAlias(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            adapter = reg.lookup("2024-11-05");
            test.verifyEqual(adapter.Version, "2025-06-18");
        end

        function tLookupUnknownVersionThrows(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            test.verifyError(@() reg.lookup("9999-99-99"), ...
                'prodserver:mcp:UnsupportedProtocolVersion');
        end

        function tSingletonReturnsSameInstance(test)
            r1 = prodserver.mcp.protocol.ProtocolRegistry.instance();
            r2 = prodserver.mcp.protocol.ProtocolRegistry.instance();
            test.verifyTrue(r1 == r2);
        end

        function tAdapterClassesReturnsNames(test)
            % The named adapters must be found -- that is a real claim, and
            % build.m depends on these exact class names to pull the packages
            % into the CTF archive. The COUNT is not asserted here; see
            % tEveryDiscoveredAdapterIsRegistered, which states the invariant
            % that survives a third adapter.
            names = prodserver.mcp.protocol.ProtocolRegistry.adapterClasses();
            test.verifyClass(names, 'string');
            test.verifyTrue(ismember( ...
                "prodserver.mcp.protocol.v20250618.Adapter", names));
            test.verifyTrue(ismember( ...
                "prodserver.mcp.protocol.v20260728.Adapter", names));
        end

        function tDetectMetaField(test)
            C = prodserver.mcp.protocol.v20260728.Constants;
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{}});
            meta = struct(C.MetaProtocolVersion_Field, C.Version, ...
                C.MetaCapabilities_Field, struct());
            jrpc = struct('method', 'tools/list', ...
                'params', struct('x_meta', meta));
            adapter = reg.detect(request, jrpc);
            test.verifyEqual(adapter.Version, "2026-07-28");
        end

        function tLookupV20260728Version(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            adapter = reg.lookup("2026-07-28");
            test.verifyEqual(adapter.Version, "2026-07-28");
        end

        function tLookup20250326Alias(test)
        % 2025-06-18 tells a server with no MCP-Protocol-Version header to
        % assume 2025-03-26, so that version has to resolve rather than 400.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            adapter = reg.lookup("2025-03-26");
            test.verifyEqual(adapter.Version, "2025-06-18");
        end

        function tAliasesAreNotAdvertised(test)
        % Aliases route; they are not versions this server offers. If they
        % leaked into supportedVersions they would leak into the `supported`
        % payload on an UnsupportedProtocolVersionError and into initialize
        % negotiation, offering a revision no adapter implements (D48).
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            versions = reg.supportedVersions();
            test.verifyFalse(ismember("2024-11-05", versions));
            test.verifyFalse(ismember("2025-03-26", versions));
        end

        % --- Attribution: which protocol does the request's SHAPE name? ---

        function tMetaBeatsInitialize(test)
        % The precedence rule, and the reason attribution is ordered rather
        % than a search for a unique match. An initialize request that also
        % carries per-request _meta satisfies both adapters' shape
        % predicates; 2026-07-28 says _meta decides, so the newer revision
        % must win instead of the ambiguity being reported as an error.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{}});
            jrpc = metaRequest("initialize", "2026-07-28");
            test.verifyEqual(reg.attribute(request, jrpc).Version, ...
                "2026-07-28");
        end

        function tMetaWithoutVersionIsStillAttributed(test)
        % Per-request _meta present but declaring no version. Attribution is
        % structural, so this is unmistakably a 2026-07-28 request and must
        % reach that adapter, where validateMeta answers
        % MissingProtocolVersion. Keying attribution on the protocolVersion
        % field alone would send it to UnattributableRequest instead.
            C = prodserver.mcp.protocol.v20260728.Constants;
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{}});
            jrpc = struct('method', 'tools/list', ...
                'params', struct(prodserver.mcp.MCPConstants.MetaField, ...
                    struct(C.MetaCapabilities_Field, struct())));
            test.verifyEqual(reg.detect(request, jrpc).Version, "2026-07-28");
        end

        function tLegacyMetaInSessionIsNotModern(test)
        % The Codex regression. A 2025-06-18 client puts progressToken in
        % _meta -- a key reserved in both eras -- on a request inside its
        % session. Only per-request fields mark a 2026-07-28 request, so
        % this belongs to the session's revision, not to a validateMeta
        % refusal for a protocolVersion the client never had to send.
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{Constants.SessionId, 'abc-123'; ...
                  prodserver.mcp.MCPConstants.ProtocolVersion, '2025-06-18'}});
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'tools/list', ...
                'params', struct(prodserver.mcp.MCPConstants.MetaField, ...
                    struct('progressToken', 0)));
            test.verifyEqual(reg.detect(request, jrpc).Version, "2025-06-18");
        end

        function tSessionHeaderOnNonInitializeIsAttributed(test)
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{Constants.SessionId, 'abc-123'}});
            jrpc = struct('method', 'tools/list');
            test.verifyEqual(reg.attribute(request, jrpc).Version, ...
                "2025-06-18");
        end

        % --- Resolution: does the stated VERSION agree? ---

        function tHeaderContradictingMetaIsAMismatch(test)
        % The regression test for the trap this phase was written to avoid.
        % Attributing by MCP-Protocol-Version would hand this request to the
        % 2025-06-18 adapter, which makes no header/_meta comparison anywhere,
        % and the mandatory -32020 would be served as a 200.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, '2025-06-18'}});
            jrpc = metaRequest("tools/list", "2026-07-28");
            test.verifyError(@() reg.detect(request, jrpc), ...
                'prodserver:mcp:HeaderMismatch');
        end

        function tMismatchOutranksUnsupportedVersion(test)
        % Both answers are 400, so the status cannot distinguish them, but
        % -32020 is the diagnosis the spec mandates for this comparison and
        % an unknown version in _meta must not mask it with -32022.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, '2026-07-28'}});
            jrpc = metaRequest("tools/list", "2027-01-01");
            test.verifyError(@() reg.detect(request, jrpc), ...
                'prodserver:mcp:HeaderMismatch');
        end

        function tUnknownMetaVersionIsUnsupported(test)
        % With no header there is nothing to mismatch against, so the
        % unknown version itself is the complaint.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{}});
            jrpc = metaRequest("tools/list", "1999-01-01");
            test.verifyError(@() reg.detect(request, jrpc), ...
                'prodserver:mcp:UnsupportedProtocolVersion');
        end

        function tAgreeingHeaderAndMetaResolve(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, '2026-07-28'}});
            jrpc = metaRequest("tools/list", "2026-07-28");
            test.verifyEqual(reg.detect(request, jrpc).Version, "2026-07-28");
        end

        function tUnknownHeaderVersionIsUnsupported(test)
        % 2025-06-18 makes an unsupported MCP-Protocol-Version a hard 400,
        % so the header is checked even when its answer is not used to pick
        % the adapter.
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{Constants.SessionId, 'abc-123'; ...
                  prodserver.mcp.MCPConstants.ProtocolVersion, '1999-01-01'}});
            jrpc = struct('method', 'tools/list');
            test.verifyError(@() reg.detect(request, jrpc), ...
                'prodserver:mcp:UnsupportedProtocolVersion');
        end

        function tAbsentHeaderIsNotAnError(test)
        % Absence must not fall into the unsupported-version branch: a
        % 2025-06-18 client need not send the header at all, and the spec
        % says to assume 2025-03-26.
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{Constants.SessionId, 'abc-123'}});
            jrpc = struct('method', 'tools/list');
            test.verifyEqual(reg.detect(request, jrpc).Version, "2025-06-18");
        end

        function tInitializeOutranksANewerVersionHeader(test)
        % The residual case, decided rather than left to code order:
        % initialize selects 2025-06-18 unconditionally and there is no
        % _meta here for the header to contradict, so the header is
        % advisory. Not an error -- the version is supported, just not what
        % the shape of the request says.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{prodserver.mcp.MCPConstants.ProtocolVersion, '2026-07-28'}});
            jrpc = struct('method', 'initialize');
            test.verifyEqual(reg.detect(request, jrpc).Version, "2025-06-18");
        end

        function tAliasedHeaderResolves(test)
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', ...
                {{Constants.SessionId, 'abc-123'; ...
                  prodserver.mcp.MCPConstants.ProtocolVersion, '2024-11-05'}});
            jrpc = struct('method', 'tools/list');
            test.verifyEqual(reg.detect(request, jrpc).Version, "2025-06-18");
        end

        function tEmptyBodyWithSessionHeaderResolves(test)
        % The DELETE path: decodeBody is not strict there, so jrpc is empty.
        % Attribution has to cope with that and find the session header.
            import prodserver.mcp.protocol.v20250618.Constants
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {{Constants.SessionId, 'abc-123'}});
            test.verifyEqual(reg.detect(request, []).Version, "2025-06-18");
        end

        function tEmptyBodyNoHeadersIsUnattributable(test)
        % And a bare DELETE stays unattributable, which is what mcpHandler
        % turns into 405 rather than an error response.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            request = struct('Headers', {cell(0,2)});
            test.verifyError(@() reg.detect(request, []), ...
                'prodserver:mcp:UnattributableRequest');
        end

        function tVersionsAreOrderedNewestFirst(test)
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            versions = reg.versionsNewestFirst();
            test.verifyEqual(versions, sort(versions, 'descend'));
            test.verifyEqual(versions(1), "2026-07-28");
        end

        function tAliasesComeFromAdapters(test)
        % The registry holds no alias of its own: every alias is one some
        % adapter declared, and routes to that adapter.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            declared = string.empty(1,0);
            for v = reg.versionsNewestFirst()
                adapter = reg.lookup(v);
                for alias = adapter.versionAliases()
                    test.verifyEqual(reg.lookup(alias).Version, v, alias);
                    declared(end+1) = alias; %#ok<AGROW>
                end
            end
            test.verifyEqual(sort(string(reg.Aliases.keys)), sort(declared));
        end

        function tResolveAsksTheAttributedAdapter(test)
        % Where a revision states its version is that revision's business.
        % A body carrying a 2026-07-28 _meta states nothing to the
        % 2025-06-18 adapter, so resolve keeps that adapter's shape-based
        % answer -- and, the header being advisory there, neither checks it
        % against _meta nor raises. Asked of the 2026-07-28 adapter, the
        % same body states its version and the header must agree.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            old = reg.lookup("2025-06-18");
            new = reg.lookup("2026-07-28");
            jrpc = metaRequest('tools/list', "2026-07-28");
            request = struct('Headers', {{ ...
                prodserver.mcp.MCPConstants.ProtocolVersion, '2025-06-18'}});

            test.verifyEqual(old.statedVersion(jrpc), "");
            test.verifyEqual(new.statedVersion(jrpc), "2026-07-28");
            test.verifyEqual(reg.resolve(old, request, jrpc).Version, ...
                "2025-06-18");
            test.verifyError(@() reg.resolve(new, request, jrpc), ...
                'prodserver:mcp:HeaderMismatch');
        end

        function tRequestedVersionFallsBackToHeader(test)
        % The `requested` member of the unsupported-version payload: the
        % stated version when there is one, else the header.
            reg = prodserver.mcp.protocol.ProtocolRegistry.instance();
            new = reg.lookup("2026-07-28");
            old = reg.lookup("2025-06-18");
            request = struct('Headers', {{ ...
                prodserver.mcp.MCPConstants.ProtocolVersion, '1999-01-01'}});
            jrpc = metaRequest('tools/list', "2030-01-01");

            test.verifyEqual(new.requestedVersion(jrpc, request), "2030-01-01");
            test.verifyEqual(old.requestedVersion(jrpc, request), "1999-01-01");
            test.verifyEqual(new.requestedVersion([], request), "1999-01-01");
            test.verifyEqual(new.requestedVersion(), "");

            answer = old.unsupportedVersionAnswer(-1, jrpc, request);
            test.verifyEqual(answer.code, -1);
            test.verifyEqual(answer.httpCode, 400);
            test.verifyEqual(answer.data.requested, "1999-01-01");
            test.verifyEqual(answer.data.supported, reg.supportedVersions());
        end

        function tInputErrorRuleFromAdapter(test)
            % Each revision's adapter states the rule; no revision gets a
            % default.
            f = @prodserver.mcp.protocol.inputErrorsAreToolErrors;
            test.verifyFalse(f("2025-06-18"));
            test.verifyTrue(f("2026-07-28"));
            test.verifyError(@() f("1999-01-01"), ...
                "prodserver:mcp:UnsupportedProtocolVersion");
        end

    end

end

function jrpc = metaRequest(method, version)
%metaRequest A 2026-07-28 request body declaring the given version.
    C = prodserver.mcp.protocol.v20260728.Constants;
    MetaField = prodserver.mcp.MCPConstants.MetaField;
    jrpc.jsonrpc = "2.0";
    jrpc.id = 1;
    jrpc.method = method;
    jrpc.params.(MetaField).(C.MetaProtocolVersion_Field) = version;
    jrpc.params.(MetaField).(C.MetaCapabilities_Field) = struct();
end
