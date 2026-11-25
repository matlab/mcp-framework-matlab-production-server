classdef TraceContext
%TraceContext A W3C trace context parsed from untrusted text (FND-24, FND-36 to FND-38).
%   A value class: the constructor applies the trace-context rules, so code
%   downstream requires the type rather than re-checking. An invalid
%   traceparent gives an invalid TraceContext (IsValid false), never an
%   error: trace context is advisory, so a bad value is ignored, never
%   rejected (FND-37).
%
%     tc = TraceContext(traceparent, tracestate)
%     tc = TraceContext.fromMeta(jrpc)       params.x_meta.traceparent and .tracestate
%     tc = TraceContext.fromHeaders(request) the traceparent and tracestate headers
%     [tp, ts] = TraceContext.metaFields(jrpc)       fromMeta's text, unparsed
%     [tp, ts] = TraceContext.headerFields(request)  fromHeaders' text, unparsed
%     [parent, link] = TraceContext.select(meta, header)
%     carrier = textMapCarrier(tc)           an Nx2 string array
%
%   select picks the request's trace (FND-36): _meta's context if valid,
%   else the header's if valid, else an invalid one (a new root); and the
%   header's context as a link when both are valid and their trace IDs
%   differ. The tracestate comes from the carrier that supplied the parent
%   (FND-38). baggage is never read.
%
%   No dependency on OpenTelemetry-MATLAB, so an archive built without
%   tracing can still put the trace on its log lines (Log.setContext).

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Invariant: IsValid => TraceParent matches the traceparent rule, and TraceId and SpanId are its
%              second and third fields
%              not IsValid => TraceParent, TraceState, TraceId and SpanId are ""
%              TraceState is "" unless it matched the tracestate rule and IsValid

    properties (SetAccess = immutable)
        IsValid (1,1) logical = false
        TraceParent (1,1) string = ""
        TraceState (1,1) string = ""
        TraceId (1,1) string = ""
        SpanId (1,1) string = ""
    end

    properties (Constant, Access = private)
        % W3C Trace Context level 1: version-traceid-parentid-flags, all
        % lowercase hex, exactly 55 characters. Version ff is invalid;
        % all-zero IDs are invalid. A later version is accepted only when it
        % has these four fields and nothing after them. W3C lets a parser
        % accept a later version's extra fields after the flags; this one
        % rejects such a value, so the context is invalid and left out.
        ParentPattern = "^(?!ff)[0-9a-f]{2}-(?!0{32})[0-9a-f]{32}-(?!0{16})[0-9a-f]{16}-[0-9a-f]{2}$"
        % One tracestate list member: a key, "=", and a value that holds no
        % comma or equals sign.
        MemberPattern = "^[a-z0-9][a-z0-9_*/@-]{0,255}=[\x20-\x2b\x2d-\x3c\x3e-\x7e]{0,255}$"
        TraceParentLength = 55
        MaxTraceStateLength = 512
        MaxTraceStateMembers = 32
    end

    methods
        function tc = TraceContext(traceparent, tracestate)
        %TraceContext Parse a traceparent and an optional tracestate.

        % Contract:
        %   Kind:      query
        %   Requires:  none (any value; a non-text value is invalid)
        %   Ensures:   as the class Invariant
        %   Raises:    none

            arguments
                traceparent = ""
                tracestate = ""
            end
            try
                tp = prodserver.mcp.internal.TraceContext.text(traceparent);
                if strlength(tp) ~= prodserver.mcp.internal.TraceContext.TraceParentLength || ...
                        isempty(regexp(tp, prodserver.mcp.internal.TraceContext.ParentPattern, "once"))
                    return
                end
                tc.IsValid = true;
                tc.TraceParent = tp;
                tc.TraceId = extractBetween(tp, 4, 35);
                tc.SpanId = extractBetween(tp, 37, 52);
                tc.TraceState = prodserver.mcp.internal.TraceContext.validState(tracestate);
            catch
                % Never raises: whatever went wrong, the context is invalid.
            end
        end

        function carrier = textMapCarrier(tc)
        %textMapCarrier The context as an Nx2 string array: traceparent and, if
        %   there is one, tracestate. Empty (0x2) for an invalid context. The
        %   form opentelemetry.context.propagation.TextMapCarrier takes; this
        %   method calls nothing.

        % Contract:
        %   Kind:      query
        %   Requires:  none
        %   Ensures:   tc.IsValid => the first row is ["traceparent", tc.TraceParent]; else carrier is 0x2
        %   Raises:    none

            arguments
                tc (1,1) prodserver.mcp.internal.TraceContext
            end
            carrier = strings(0, 2);
            if ~tc.IsValid
                return
            end
            carrier = ["traceparent", tc.TraceParent];
            if strlength(tc.TraceState) > 0
                carrier(end+1, :) = ["tracestate", tc.TraceState];
            end
        end
    end

    methods (Static)
        function tc = fromMeta(jrpc)
        %fromMeta The context in params._meta (decoded as x_meta), on any revision.

        % Contract:
        %   Kind:      query
        %   Requires:  none (jrpc may be [], or lack params or x_meta)
        %   Ensures:   tc reflects params.x_meta.traceparent and .tracestate; invalid when absent
        %   Raises:    none

            arguments
                jrpc
            end
            [parent, state] = prodserver.mcp.internal.TraceContext.metaFields(jrpc);
            tc = prodserver.mcp.internal.TraceContext(parent, state);
        end

        function tc = fromHeaders(request)
        %fromHeaders The context in the request's traceparent and tracestate
        %   headers, matched ignoring case.

        % Contract:
        %   Kind:      query
        %   Requires:  none (request may lack Headers, or have an empty one)
        %   Ensures:   tc reflects the first traceparent and tracestate headers, matched ignoring case;
        %              invalid when absent
        %   Raises:    none

            arguments
                request
            end
            [parent, state] = prodserver.mcp.internal.TraceContext.headerFields(request);
            tc = prodserver.mcp.internal.TraceContext(parent, state);
        end

        function [traceparent, tracestate] = metaFields(jrpc)
        %metaFields The text of params._meta's traceparent and tracestate
        %   (decoded as x_meta), unparsed. Each is "" when it is absent, is
        %   not text, or is longer than any valid value, so what a caller
        %   keeps is bounded. Reads fields only: a caller can take the text
        %   now and parse it later, keeping no part of the message.

        % Contract:
        %   Kind:      query
        %   Requires:  none (jrpc may be [], or lack params or x_meta)
        %   Ensures:   traceparent and tracestate are trimmed string scalars, at most 55 and 512
        %              characters; TraceContext(traceparent, tracestate) equals fromMeta(jrpc)
        %   Raises:    none

            arguments
                jrpc
            end
            traceparent = "";
            tracestate = "";
            try
                if ~isstruct(jrpc) || ~isscalar(jrpc) || ~isfield(jrpc, "params") || ...
                        ~isstruct(jrpc.params) || ~isscalar(jrpc.params) || ...
                        ~isfield(jrpc.params, prodserver.mcp.MCPConstants.MetaField)
                    return
                end
                meta = jrpc.params.(prodserver.mcp.MCPConstants.MetaField);
                if ~isstruct(meta) || ~isscalar(meta) || ~isfield(meta, "traceparent")
                    return
                end
                state = "";
                if isfield(meta, "tracestate")
                    state = meta.tracestate;
                end
                [traceparent, tracestate] = prodserver.mcp.internal.TraceContext.bounded( ...
                    meta.traceparent, state);
            catch
            end
        end

        function [traceparent, tracestate] = headerFields(request)
        %headerFields The text of the request's traceparent and tracestate
        %   headers, matched ignoring case, unparsed and bounded as
        %   metaFields bounds them. A missing or empty Headers field, or one
        %   that isn't an Nx2 list, gives "".

        % Contract:
        %   Kind:      query
        %   Requires:  none (request may lack Headers, or have an empty one)
        %   Ensures:   traceparent and tracestate are trimmed string scalars, at most 55 and 512
        %              characters; TraceContext(traceparent, tracestate) equals fromHeaders(request)
        %   Raises:    none

            arguments
                request
            end
            traceparent = "";
            tracestate = "";
            try
                parent = prodserver.mcp.internal.requestHeader(request, "traceparent");
                if isempty(parent)
                    return
                end
                [traceparent, tracestate] = prodserver.mcp.internal.TraceContext.bounded( ...
                    parent, prodserver.mcp.internal.requestHeader(request, "tracestate"));
            catch
            end
        end

        function [parent, link] = select(meta, header)
        %select Pick the request's trace context and the link (FND-36).
        %   _meta's context if it's valid, else the header's if valid, else
        %   an invalid context: a new root. LINK is the header's context when
        %   both are valid and their trace IDs differ, else invalid.

        % Contract:
        %   Kind:      query
        %   Requires:  meta and header are TraceContexts                (arguments)
        %   Ensures:   parent is meta if meta.IsValid, else header if header.IsValid, else invalid
        %              link.IsValid == (meta.IsValid && header.IsValid && meta.TraceId ~= header.TraceId), and then
        %              link == header
        %   Raises:    none

            arguments
                meta (1,1) prodserver.mcp.internal.TraceContext
                header (1,1) prodserver.mcp.internal.TraceContext
            end
            none = prodserver.mcp.internal.TraceContext();
            link = none;
            if meta.IsValid
                parent = meta;
                if header.IsValid && header.TraceId ~= meta.TraceId
                    link = header;
                end
            elseif header.IsValid
                parent = header;
            else
                parent = none;
            end
        end
    end

    methods (Static, Access = private)
        function s = text(v)
        % V as a trimmed string scalar, or "" when it isn't text.
            s = "";
            if prodserver.mcp.validation.isTextScalar(v)
                s = strip(string(v));
            end
        end

        function [traceparent, tracestate] = bounded(parent, state)
        % PARENT and STATE as text, each "" when longer than any valid value:
        % "", not cut, so a value that was invalid stays invalid.
            import prodserver.mcp.internal.TraceContext
            traceparent = TraceContext.text(parent);
            if strlength(traceparent) > TraceContext.TraceParentLength
                traceparent = "";
            end
            tracestate = TraceContext.text(state);
            if strlength(tracestate) > TraceContext.MaxTraceStateLength
                tracestate = "";
            end
        end

        function s = validState(v)
        % V when it's a valid tracestate, else "" (FND-38). Every character
        % must be printable ASCII or a tab, so a returned value can never
        % carry a line break into a header; only space and tab, W3C's
        % optional whitespace, may surround a member.
            s = prodserver.mcp.internal.TraceContext.text(v);
            if strlength(s) == 0 || strlength(s) > prodserver.mcp.internal.TraceContext.MaxTraceStateLength || ...
                    ~isempty(regexp(s, "[^\x20-\x7e\t]", "once"))
                s = "";
                return
            end
            members = regexprep(split(s, ","), "^[ \t]+|[ \t]+$", "");
            if numel(members) > prodserver.mcp.internal.TraceContext.MaxTraceStateMembers || ...
                    any(cellfun(@isempty, regexp(cellstr(members), ...
                    prodserver.mcp.internal.TraceContext.MemberPattern, "once")))
                s = "";
            end
        end
    end
end
