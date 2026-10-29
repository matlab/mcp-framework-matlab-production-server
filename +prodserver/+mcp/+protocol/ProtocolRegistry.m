classdef ProtocolRegistry < handle
%ProtocolRegistry Discovers and caches protocol adapters.
%   Uses meta.package introspection to find all concrete Adapter
%   subclasses in the +protocol namespace, and routes each request to one
%   of them. Routing is two ordered steps -- see detect.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Adapters
        Aliases
    end

    methods (Access = private)
        function obj = ProtocolRegistry()
            obj.Adapters = containers.Map();
            obj.Aliases = containers.Map('KeyType', 'char', 'ValueType', 'char');

            obj.discoverAdapters();
            obj.registerAliases();
        end

        function registerAliases(obj)
        %registerAliases Route each adapter's aliases to that adapter.
        %   Aliases exist for ROUTING only -- see Adapter.versionAliases.
        %   Each revision declares its own, so the registry holds no facts
        %   about any one revision. An alias claimed twice, or naming a
        %   registered version, would make routing depend on discovery
        %   order, so it is an error rather than a silent overwrite.
            for version = obj.versionsNewestFirst()
                for alias = obj.Adapters(char(version)).versionAliases()
                    if obj.Adapters.isKey(char(alias)) || ...
                            obj.Aliases.isKey(char(alias))
                        error('prodserver:mcp:AliasConflict', ...
                            ['Protocol version alias %s, declared by the ' ...
                             '%s adapter, is already registered.'], ...
                            alias, version);
                    end
                    obj.Aliases(char(alias)) = char(version);
                end
            end
        end

        function discoverAdapters(obj)
            names = prodserver.mcp.protocol.ProtocolRegistry.adapterClasses();
            for i = 1:numel(names)
                adapter = feval(names(i));
                obj.Adapters(char(adapter.Version)) = adapter;
            end
            if obj.Adapters.Count == 0
                error('prodserver:mcp:NoAdaptersFound', ...
                    'No protocol adapters found in +protocol namespace.');
            end
        end
    end

    methods
        function adapter = detect(obj, request, jrpc)
        %detect Select the protocol adapter that must serve a request.
        %   Two ordered steps, not one. attribute picks an adapter from the
        %   request's SHAPE; resolve then checks it against the version
        %   STRING the request states, and corrects or rejects it.
        %
        %   Collapsing them into a single match on MCP-Protocol-Version
        %   looks equivalent and is not. A request whose header says
        %   2025-06-18 and whose _meta says 2026-07-28 would be handed to
        %   the 2025-06-18 adapter, which never compares the two -- that
        %   comparison is the 2026-07-28 adapter's checkStatedVersion, and
        %   only the adapter attribution chose is asked -- and the
        %   mandatory -32020 would go out as a 200.
        %
        %   mcpHandler calls the two steps separately rather than using this
        %   composition, because it needs to keep the attributed adapter when
        %   resolve raises: that adapter is what its error path asks for the
        %   codes whose correctness depends on the declared revision. This
        %   method remains the statement of the ordering, and the form to use
        %   wherever the intermediate result is not needed.
            adapter = obj.resolve(obj.attribute(request, jrpc), request, jrpc);
        end

        function adapter = attribute(obj, request, jrpc)
        %attribute Pick an adapter from the request's shape alone.
        %   No version strings, no lookup, no protocol-specific error codes,
        %   so this step cannot fail in a way that presupposes the very
        %   protocol it is deciding. Adapter.matches is the per-adapter shape
        %   predicate: per-request _meta fields (not merely params._meta)
        %   for 2026-07-28, an `initialize` method or an Mcp-Session-Id
        %   header for 2025-06-18.
        %
        %   Adapters are consulted newest version first, and that ordering is
        %   the precedence rule rather than an accident of iteration.
        %   2026-07-28 states it unconditionally -- a request carrying
        %   per-request _meta is served by that revision, while an
        %   `initialize` request selects 2025-06-18 -- so a request that is
        %   BOTH, an `initialize` carrying _meta, must come out as 2026-07-28.
        %   ISO 8601 version strings sort lexicographically in chronological
        %   order, so a descending sort of the keys says exactly that, and
        %   keeps saying it when a later revision is added.
            for version = obj.versionsNewestFirst()
                a = obj.Adapters(char(version));
                if a.matches(request, jrpc)
                    adapter = a;
                    return
                end
            end

            % No registered revision recognizes the request's shape -- today:
            % no params._meta, no `initialize`, no session header. We ELECT
            % to report this as a 2026-07-28 request with missing _meta, which
            % mapPreDetectionError turns into -32602/400. That is an
            % engineering choice, not a dual mandate: 2026-07-28's MUST on
            % missing _meta is unambiguous, but 2025-06-18's nearest clause
            % is a SHOULD conditional on "servers that require a session ID",
            % and this server does not. See design-decisions.md D43.
            %
            % The message names no revision's markers: which shapes are
            % recognized is each adapter's business (Adapter.matches), and a
            % list here would go stale with the next revision.
            error('prodserver:mcp:UnattributableRequest', ...
                ['Cannot attribute the request to a protocol version: its ' ...
                 'shape matches none of the supported revisions (%s).'], ...
                strjoin(obj.versionsNewestFirst(), ", "));
        end

        function adapter = resolve(obj, attributed, request, jrpc)
        %resolve Check the attributed adapter against the stated version.
        %   Only one version question genuinely has to be settled before the
        %   serving adapter is known: whether the MCP-Protocol-Version header
        %   agrees with a version the body states. Attribution has already
        %   established which revision's rules apply, so the attributed
        %   adapter is asked -- statedVersion for where the body states one,
        %   checkStatedVersion for the comparison -- and this method names
        %   no revision. Every other header question stays in the adapter
        %   (stage D).
            pv = prodserver.mcp.internal.headerVersion(request);
            stated = attributed.statedVersion(jrpc);

            if strlength(stated) > 0
                % A version stated in the body is authoritative, so the
                % header can only agree with it or be wrong.
                %
                % The mismatch check precedes the lookup. Both answers are
                % 400, so the status does not depend on the order, but a
                % mismatch (-32020 under 2026-07-28) is the specific
                % diagnosis the spec mandates for exactly this comparison,
                % and an unknown stated version would otherwise mask it.
                attributed.checkStatedVersion(pv, stated);
                adapter = obj.lookup(stated);
                return
            end

            if strlength(pv) > 0
                % No stated version, so the header is the only version the
                % request states. An unsupported one is a hard 400 under
                % 2025-06-18, which is what this lookup is for -- its ANSWER
                % is discarded. It has to be: `initialize` selects
                % 2025-06-18 unconditionally and there is no stated version
                % here for the header to contradict, so a header naming any
                % other revision is advisory and the shape stands.
                %
                % lookup raises UnsupportedProtocolVersion. The attributed
                % adapter's preDetectionError hook chooses the code and the
                % payload -- see v20250618.Adapter.preDetectionError, which
                % owns the argument for answering a 2025-06-18 client with
                % -32022.
                obj.lookup(pv);
            end

            % Nothing stated, or stated only advisorily. An absent header is
            % not an error: 2025-06-18 says to assume 2025-03-26, which
            % Aliases maps onto the adapter the shape already chose.
            %
            % A per-request _meta declaring no version also lands here. The
            % attributed adapter's own validateMeta then raises
            % MissingProtocolVersion against its own mapper -- -32602/400.
            % Raising it here instead would reach mapPreDetectionError, which
            % has no row for it and would answer -32603/500.
            adapter = attributed;
        end

        function adapter = lookup(obj, version)
            version = char(version);
            if obj.Aliases.isKey(version)
                version = obj.Aliases(version);
            end
            if ~obj.Adapters.isKey(version)
                error('prodserver:mcp:UnsupportedProtocolVersion', ...
                    'Unsupported protocol version: %s', version);
            end
            adapter = obj.Adapters(version);
        end

        function versions = supportedVersions(obj)
            versions = string(obj.Adapters.keys);
        end

        function versions = versionsNewestFirst(obj)
        %versionsNewestFirst Registered versions, most recent revision first.
        %   A row vector, so it can drive a for loop directly.
            versions = sort(string(obj.Adapters.keys), 'descend');
            versions = reshape(versions, 1, []);
        end
    end

    methods (Static)
        function obj = instance()
            persistent inst
            if isempty(inst)
                inst = prodserver.mcp.protocol.ProtocolRegistry();
            end
            obj = inst;
        end

        function names = adapterClasses()
        %adapterClasses Fully-qualified names of concrete Adapter subclasses.
        %   Used at runtime by discoverAdapters and at build time by build.m
        %   to ensure adapter packages are included in CTF archives.
            pkg = meta.package.fromName('prodserver.mcp.protocol');
            if isempty(pkg)
                error('prodserver:mcp:NoProtocolPackage', ...
                    'Protocol package not found.');
            end
            adapterBase = 'prodserver.mcp.protocol.Adapter';
            names = string.empty;
            for i = 1:numel(pkg.PackageList)
                subpkg = pkg.PackageList(i);
                for j = 1:numel(subpkg.ClassList)
                    mc = subpkg.ClassList(j);
                    if ~mc.Abstract && isSubclassOf(mc, adapterBase)
                        names(end+1) = string(mc.Name); %#ok<AGROW>
                    end
                end
            end
        end
    end

end

function tf = isSubclassOf(mc, parentName)
    tf = false;
    for k = 1:numel(mc.SuperclassList)
        if strcmp(mc.SuperclassList(k).Name, parentName)
            tf = true;
            return
        end
        if isSubclassOf(mc.SuperclassList(k), parentName)
            tf = true;
            return
        end
    end
end
