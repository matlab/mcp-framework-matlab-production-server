classdef (Abstract) Adapter < handle
%Adapter Abstract base class for MCP protocol version adapters.
%   Each concrete subclass handles one MCP protocol version: detection,
%   request processing, error formatting, and response headers.

% Copyright 2026 The MathWorks, Inc.

    properties (Abstract, Constant)
        Version string
        % Whether a tools/call whose arguments fail the tool's inputSchema
        % gets result.isError (true) or JSON-RPC error -32602 (false).
        InputErrorsAreToolErrors logical
    end

    methods (Abstract)
        [result, httpCode, httpMsg, msgHeaders] = handlePost(obj, request, jrpc)
        [result, httpCode, httpMsg, msgHeaders] = handleDelete(obj, request)
        [result, httpCode, httpMsg] = formatError(obj, me, jrpc)
        headers = responseHeaders(obj, request, jrpc)
    end

    methods (Abstract, Static)
        tf = matches(request, jrpc)
    end

    methods
        function answer = preDetectionError(~, ~, ~, ~)
        %preDetectionError This revision's answer for a failure raised before
        %   it was fully selected, or [] if it has none.
        %
        %   Signature: preDetectionError(obj, identifier, jrpc, request).
        %   Returns [] (the default) or a struct with fields code, httpCode,
        %   httpMsg and data, where data may be [].
        %
        %   Only ProtocolRegistry.resolve raises after attribution, so the
        %   identifiers reaching here are HeaderMismatch and
        %   UnsupportedProtocolVersion. Everything earlier -- parse, envelope,
        %   media type, and attribution failing outright -- has no attributed
        %   adapter to ask and is answered by handler.internal's neutral arms.
        %
        %   This hook exists so that handler.internal does not have to name a
        %   revision to reach that revision's code space. It is consulted on
        %   the adapter ATTRIBUTION chose, deliberately not on the newest
        %   registered one: the -32020 answer is licensed by what the request
        %   declared, not by release order, and those coincide only while
        %   exactly one revision carries per-request _meta. Keyed on the
        %   newest adapter, a third revision would answer a 2026-07-28
        %   request with a code shaped by a revision it never asked for.
        %
        %   Defaulted rather than abstract: a revision with no opinion
        %   returns [] and the neutral arms stand.
            answer = [];
        end

        function version = statedVersion(~, ~)
        %statedVersion The protocol version a request states in its body.
        %
        %   Signature: statedVersion(obj, jrpc). Returns "" (the default) when
        %   this revision's requests carry no per-request version, or this
        %   request declares none.
        %
        %   ProtocolRegistry.resolve asks the ATTRIBUTED adapter, so that
        %   where a revision states its version -- params._meta for
        %   2026-07-28 -- is known only to that revision. A stated version is
        %   authoritative: resolve routes on it, not on the shape. The
        %   registry used to read 2026-07-28's _meta field itself, which was
        %   correct only while exactly one revision stated a version that
        %   way.
            version = "";
        end

        function checkStatedVersion(~, ~, ~)
        %checkStatedVersion Reject a version header that contradicts the body.
        %
        %   Signature: checkStatedVersion(obj, pv, stated). PV is the
        %   MCP-Protocol-Version header ("" when absent), STATED what
        %   statedVersion returned. Called by ProtocolRegistry.resolve only
        %   when STATED is non-empty, before STATED is looked up: a mismatch
        %   is a more specific diagnosis than an unknown version, and an
        %   unknown version would otherwise mask it.
        %
        %   Raises prodserver:mcp:HeaderMismatch, which this revision's
        %   preDetectionError renders. The default does nothing, as befits a
        %   revision that states no version for a header to contradict.
        end

        function aliases = versionAliases(~)
        %versionAliases Other version strings this adapter serves.
        %
        %   ROUTING only: an alias says which adapter serves a version, not
        %   that this server advertises it. ProtocolRegistry.lookup honours
        %   aliases; supportedVersions does not list them, and negotiation
        %   must not offer them (design-decisions.md D48). Each revision
        %   states its own, so the registry holds no facts about any one.
            aliases = string.empty(1,0);
        end

        function version = requestedVersion(obj, jrpc, request)
        %requestedVersion The version a rejected request asked for.
        %   The stated version when there is one, else the
        %   MCP-Protocol-Version header -- the same two places, in the same
        %   order, that ProtocolRegistry.resolve consults to reach
        %   UnsupportedProtocolVersion in the first place.
            arguments
                obj
                jrpc = []
                request = []
            end
            version = obj.statedVersion(jrpc);
            if strlength(version) == 0
                version = prodserver.mcp.internal.headerVersion(request);
            end
        end

        function answer = unsupportedVersionAnswer(obj, code, jrpc, request)
        %unsupportedVersionAnswer The preDetectionError answer to an
        %   unsupported version: CODE over 400, with the supported list and
        %   the requested version as `error.data`. CODE is the revision's
        %   choice; everything else is the same for every revision.
            answer = prodserver.mcp.protocol.preDetectionAnswer(code, ...
                prodserver.mcp.protocol.unsupportedVersionData( ...
                    obj.requestedVersion(jrpc, request)));
        end

        function data = postEncode(~, data)
        %postEncode Restore wire field names that every revision shares.
        %   Overridable. A revision with mangled field names of its own
        %   overrides this, calls the superclass first, then applies its own
        %   table -- so the shared set is inherited rather than re-listed,
        %   and a new revision gets it without having to know it exists.
        %
        %   The UI extension is here, not in a revision, because it is not
        %   versioned with the protocol: its constants live on MCPConstants
        %   alongside the other revision-neutral names. 2025-06-18 used to
        %   apply this pair from its own table and 2026-07-28 applied none,
        %   so a UI extension block went out mangled on the newer revision.
            data = prodserver.mcp.jsonrpc.restoreFieldNames(data, ...
                prodserver.mcp.protocol.Adapter.SharedFieldNames);
        end
    end

    properties (Constant, Access = protected)
        % Mangled-to-wire field names that apply to every revision.
        % restoreFieldNames renames keys only, so the same text inside a
        % string value is left alone.
        SharedFieldNames = { ...
            prodserver.mcp.MCPConstants.UIExtension_Field, ...
            prodserver.mcp.MCPConstants.UIExtension_JSON
            prodserver.mcp.MCPConstants.MatlabClass_Field, ...
            prodserver.mcp.MCPConstants.MatlabClass_JSON }
    end

end
