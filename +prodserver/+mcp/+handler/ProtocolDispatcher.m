classdef ProtocolDispatcher < handle
%ProtocolDispatcher Shared method router for MCP handlers.
%   Routes MCP method names to handler functions. Protocol-specific methods
%   (initialize, ping, server/discover) are NOT registered here — those are
%   handled by the adapter before delegation reaches the dispatcher.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Methods dictionary
    end

    methods (Access = private)
        function obj = ProtocolDispatcher()
            obj.Methods = dictionary(...
                "tools/call",                "prodserver.mcp.handler.tools.call", ...
                "tools/list",                "prodserver.mcp.handler.tools.list", ...
                "resources/read",            "prodserver.mcp.handler.resource.read", ...
                "resources/list",            "prodserver.mcp.handler.resource.list", ...
                "resources/templates/list",  "prodserver.mcp.handler.resource.templatesList");
        end
    end

    methods
        function [result, httpCode, httpMsg, msgHeaders] = dispatch(obj, jrpc, version)
        %dispatch Route a request to its handler.
        %   VERSION is the protocol revision serving this request, which the
        %   caller already holds: an adapter passes its own obj.Version. It is
        %   required rather than defaulted because the dispatcher is only ever
        %   reached through an adapter, so there is no call that legitimately
        %   does not know the answer.
        %
        %   Every handler takes it, and the four that have no use for it
        %   declare it as ~. That uniformity is the point: a handler that needs
        %   the revision must not re-derive it from the body, because the body
        %   does not say which adapter was chosen. Aliases make the two differ
        %   -- a _meta declaring 2024-11-05 is SERVED by 2025-06-18 -- so a
        %   handler deriving its own answer tags per-revision metrics with a
        %   bucket supportedVersions() excludes, and names both revisions to
        %   do it.
            arguments
                obj
                jrpc
                version (1,1) string
            end

            mth = lower(string(jrpc.method));
            if isKey(obj.Methods, mth)
                handler = obj.Methods(mth);
                [result, httpCode, httpMsg, msgHeaders] = ...
                    feval(handler, jrpc, version);
            else
                % Any method not explicitly handled -- including an
                % unsupported */list (e.g. prompts/list, whose capability is
                % not advertised) -- is Method not found. It must never be
                % answered with an empty 204 for an id-bearing request.
                error("prodserver:mcp:MethodNotFound", ...
                    "Method not found: %s", mth);
            end
        end

        function names = methodNames(obj)
            names = keys(obj.Methods);
        end

        function files = handlerFiles(obj)
        %handlerFiles Resolved file paths of all dispatched handler functions.
        %   Used at build time to include dynamically dispatched handlers
        %   in CTF archives.
            names = values(obj.Methods);
            files = arrayfun(@(f)string(which(f)), names');
        end

        function caps = capabilities(obj)
            names = keys(obj.Methods);
            prefixes = unique(extractBefore(names, "/"));
            caps = struct();
            for i = 1:numel(prefixes)
                caps.(prefixes(i)) = struct();
            end
        end
    end

    methods (Static)
        function obj = instance()
            persistent inst
            if isempty(inst)
                inst = prodserver.mcp.handler.ProtocolDispatcher();
            end
            obj = inst;
        end
    end

end
