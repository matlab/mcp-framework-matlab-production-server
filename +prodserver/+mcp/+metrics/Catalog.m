classdef Catalog < matlab.mixin.CustomDisplay
% Catalog Collection of MATLAB Production Server metrics: a snapshot of
% all those the server reported when prodserver.mcp.metrics was called.
%
%   Query it with name, archive, type, filter or scope. Displayed, it
%   summarises what it holds: its properties are protected, so MATLAB's
%   own display showed "Catalog with no properties", which looked empty.

% Copyright 2026 The MathWorks, Inc.

    properties (Access=protected)
        % Fields: name, type, archive, value
        metrics struct
        % Name of the server from which these metrics derive
        server
        % Address of that server, <scheme>://<host>:<port>, for display.
        % Without any user information, which may hold a password.
        address string = ""
    end

    methods
        function mc = Catalog(data,uri)

            % Insist on an even number of lines.
            if mod(numel(data),2) ~= 0
                error("prodserver:mcp:UnevenMetricsReport", ...
                    "Metrics report must have an even number of lines. It " + ...
                    "has %d which is not an even number.", numel(data));
            end

            % A plain server address names no archive, which only the
            % display uses, so leave the name empty rather than fail here.
            mc.server = prodserver.mcp.internal.archiveFromEndpoint(uri);
            % redactURI, as every message that shows an address does: its
            % user information ends at the last @, not the first.
            mc.address = prodserver.mcp.io.redactURI(string(regexp( ...
                char(string(uri)), "^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]+", ...
                "match", "once")));

            % Parse data into a structure. Each metric consists of two lines:
            % 
            %   # TYPE matlabprodserver_up_time_seconds counter
            %   matlabprodserver_up_time_seconds 46.0555
            %
            % Custom metrics may also have an archive name appended:
            %
            %   # TYPE test_function_execution_count counter
            %   test_function_execution_count{archive="test_metrics_2"} 1
            %
            % Multiple archives may have a metric with the same name. 
            %
            % Create structure array with fields "name", "archive", "suffix", 
            % "type" and "value".
            %
            %   name = "matlabprodserver_up_time_seconds";
            %   archive = "";
            %   suffix = [];
            %   type = "counter";
            %   value = 46.0555;
            %
            % archive may be empty, if the metrics service does not report an
            % archive for a given metric -- instance-wide metrics typically
            % do not have an archive name.
            %
            % Archive names reported by the server are quite literal: they 
            % will include a numeric suffix if multiple archives of the
            % same name have been deployed to that server. This suffix is an
            % implementation detail and is removed by the MetricsCatalog.
            
            % Allocate structure array of the right size.
            N = numel(data)/2;
            void = cell(N,1);
            mc.metrics = struct("name", void, "type", void, ...
                "archive", void, "suffix", void, "value", void);

            % Parse the data
            archivePattern = "{" + wildcardPattern(except="}") + "}";
            suffixPattern = "_" + digitsPattern + textBoundary("end");
            for n = 1:2:numel(data)
                idx = (n+1)/2;
                nvp = split(data(n+1));
                mc.metrics(idx).name = nvp(1);
                labels = extract(mc.metrics(idx).name, archivePattern);
                mc.metrics(idx).name = erase(mc.metrics(idx).name, labels);
                % Every metric has one archive, "" if it has no archive
                % label, and a suffix, [] if that has none: scope, filter
                % and the display line the fields of all the metrics up.
                % The label is archive="...", whole, among any others, not
                % the end of another label's name, such as myarchive.
                archiveLabel = "";
                if ~isempty(labels)
                    found = regexp(labels(1), ...
                        '(^\{|,)\s*archive="([^"]*)"', "tokens", "once");
                    if ~isempty(found)
                        archiveLabel = found(2);
                    end
                end
                mc.metrics(idx).archive = erase(archiveLabel, suffixPattern);
                suffix = erase(extract(archiveLabel, suffixPattern), "_");
                if isempty(suffix)
                    mc.metrics(idx).suffix = [];
                else
                    mc.metrics(idx).suffix = suffix(1);
                end
                mc.metrics(idx).value = nvp(2);
                mc.metrics(idx).type = split(data(n));
                mc.metrics(idx).type = mc.metrics(idx).type(end);
                if strcmpi(mc.metrics(idx).type, "counter") || ...
                        strcmpi(mc.metrics(idx).type, "gauge")
                    mc.metrics(idx).value = double(mc.metrics(idx).value);
                end
            end
        end

        function metrics = filter(mc, opts)
        %filter Apply one or more filters to the list of metrics.
        % All filter inputs optional -- with none, returns all known
        % metrics.

            arguments
                mc prodserver.mcp.metrics.Catalog
                % Metric must be of this kind. match doesn't apply to it.
                opts.scope prodserver.mcp.metrics.Scope = "All"

                % Metric archive must match this pattern
                opts.archive pattern = pattern.empty

                % Metric name must match this pattern
                opts.name pattern = pattern.empty

                % Metric must have this type
                opts.type prodserver.mcp.metrics.Type = "Any"

                % Exact or Contains pattern matching for name and archive
                opts.match prodserver.mcp.metrics.Match = "Exact"

                % Filter by suffix. Suffix may be a set of doubles or a
                % function. If a set, result is filtered by intersection of
                % suffix with set. If a function, result is filtered by
                % intersection with results returned by function. NaN means
                % archives with no suffix.
                opts.suffix = []
              
            end

            metrics = mc.metrics;

            % All metrics of the kind
            if opts.scope ~= prodserver.mcp.metrics.Scope.All && ~isempty(metrics)
                metrics = metrics(isKind(metrics, opts.scope));
            end

            % Of those, all matching name
            if ~isempty(opts.name) && ~isempty(metrics)
                n = [metrics.name];
                switch opts.match
                    case "Exact"
                        i = matches(n,opts.name);
                    case "Contains"
                        i = contains(n,opts.name);
                end
                metrics = metrics(i);
            end

            % Of those, all matching archive
            if ~isempty(opts.archive) && ~isempty(metrics)
                a = [metrics.archive];
                switch opts.match
                    case "Exact"
                        i = matches(a,opts.archive);
                    case "Contains"
                        i = contains(a,opts.archive);
                end
                metrics = metrics(i);
            end

            % Of those, all matching the type
            if opts.type ~= prodserver.mcp.metrics.Type.Any && ~isempty(metrics)
                t = [metrics.type];
                i = strcmpi(t,opts.type);
                metrics = metrics(i);
            end

            % Of those, all with archive suffix in the given set
            if ~isempty(opts.suffix) && ~isempty(metrics)

                % Some metrics may have no suffix -- first deployment, for
                % example. But s must be the same size as metrics in order
                % for ismember to work properly. Can't use [metrics.suffix]
                % to create s, because it drops empty [].
                s = arrayfun(@(m)str2double(m.suffix),metrics);

                % If opts.suffix is a function handle, filter the existing
                % suffixes by opts.suffix first, then intersect that set
                % with the complete set to yield the result. So, passing
                % @max, for example, returns the metrics for the archive
                % with the largest suffix. Which is mostly useful when
                % there are multiple archives with the same name.
                if isa(opts.suffix,'function_handle')
                    ft = functions(opts.suffix);
                    if contains(ft.type,'simple',IgnoreCase=true) && ...
                            isempty(which(func2str(opts.suffix)))
                        error("prodserver:mcp:NonExistentMetricsSuffixFunction", ...
                            "Metrics suffix function cannot be found.");
                    end

                    if nargin(opts.suffix) == 0
                        error("prodserver:mcp:InvalidMetricsSuffixFunction", ...
      "Metrics suffix function must have at least one input parameter.");
                    end
                    try
                        sfx = opts.suffix(s);
                    catch ex
                        error("prodserver:mcp:MetricsSuffixFunctionFailed", ...
                            "Metrics suffix function error: %s", ex.message);
                    end
                    % Invalid function output cannot be used as suffix values.
                    if ~isnumeric(sfx) && ~islogical(sfx) 
                        error("prodserver:mcp:InvalidMetricsSuffix", ...
                            "Suffix function must return numeric values.");
                    end
                elseif prodserver.mcp.validation.istext(opts.suffix)
                    sfx = str2double(opts.suffix);
                    if any(isnan(sfx))
                        error("prodserver:mcp:InvalidTextMetricsSuffix", ...
                            "Text suffixes must convert to numbers, not NaN");
                    end
                elseif isnumeric(opts.suffix)
                    sfx = opts.suffix;
                else
                    error("prodserver:mcp:InvalidMetricsSuffix", ...
                        "Suffix must be numeric, text, or a function handle.");
                end

                % Logical values are allowed as masks only -- they must be
                % the same size as the metrics list.
                if islogical(sfx) 
                    if isequal(size(sfx),size(s))
                        sfx = s(sfx); 
                    else
                        error("prodserver:mcp:InvalidMetricsMaskSize", ...
                            "Logical index size (%d) must match metrics " + ...
                            "list length (%d).", numel(sfx), numel(s));
                    end
                end
 
                % If there are any NaNs in the list of target suffixes, match
                % them against the NaNs in the returned metric suffix. At
                % this point NaN means "no suffix".
                i = ismember(s,sfx) | (isnan(s) & any(isnan(sfx)));
                metrics = metrics(i);
            end
        end

        function metrics = name(mc, n, opts)
        %name All metrics of a given name.
        %
        %  metrics = name(catalog, n) returns a structure array with fields
        %     "name", "type", "archive", "value" containing all the metrics
        %     with name n.

            arguments
                mc prodserver.mcp.metrics.Catalog
                n pattern { mustBeNonempty }
                opts.match prodserver.mcp.metrics.Match = "Exact"
            end

            metrics = filter(mc,name=n,match=opts.match);
        end

        function metrics = archive(mc, a, opts)
        %archive All metrics from a given archive.
        %  metrics = archive(catalog, a) returns a structure array with 
        %     fields "name", "type", "archive", "value" containing all the 
        %     metrics from archive a. 

            arguments
                mc prodserver.mcp.metrics.Catalog
                a pattern
                opts.suffix = []
                opts.match prodserver.mcp.metrics.Match = "Exact"
            end

            metrics = filter(mc,archive=a,match=opts.match,suffix=opts.suffix);
        end

        function metrics = type(mc, t)
        %type All metrics of a given type.
        %
        %  metrics = type(catalog, t) returns a structure array with fields
        %     "name", "type", "archive", "value" containing all the metrics
        %     with type t.

            arguments
                mc prodserver.mcp.metrics.Catalog
                t prodserver.mcp.metrics.Type
            end

            metrics = filter(mc,type=t);
        end

        function metrics = scope(mc, s)
        %scope All metrics of a given kind.
        %
        %  metrics = scope(catalog, s) returns a structure array with fields
        %     "name", "type", "archive", "value" containing all the metrics
        %     of kind s, from every archive. To select one archive's, use
        %     filter(catalog, scope=s, archive=a).

            arguments
                mc prodserver.mcp.metrics.Catalog
                s prodserver.mcp.metrics.Scope
            end

            metrics = filter(mc,scope=s);
        end
    end

    methods (Access = protected)

        function displayScalarObject(mc)
        % A summary, not the default display, which shows only public
        % properties and so said "Catalog with no properties".
            fprintf("%s\n", summary(mc, ...
                matlab.mixin.CustomDisplay.getClassNameForHeader(mc)));
        end

        function txt = summary(mc, className)
        %summary What the catalog holds, as displayScalarObject shows it.
        %   CLASSNAME is the class name for the first line, as a link in the
        %   Command Window.
            from = "MATLAB Production Server";
            if strlength(mc.address) > 0
                from = from + " " + mc.address;
            end
            if strlength(mc.server) > 0
                from = from + ", for archive " + mc.server;
            end
            hint = "  Query it with name, archive, type, filter or scope, " + ...
                "for example catalog.name(""MCP_Framework_Request"")." + ...
                newline + "  A snapshot: call prodserver.mcp.metrics " + ...
                "again to update it.";

            n = numel(mc.metrics);
            if n == 0
                txt = "  " + className + " with no metrics from " + from + ...
                    ". A server that has just started may have none yet.";
                return
            end

            instance = scope(mc, prodserver.mcp.metrics.Scope.Instance);
            mcp = scope(mc, prodserver.mcp.metrics.Scope.MCP);
            counts = sprintf("    %d instance (matlabprodserver_*)    " + ...
                "%d MCP framework (%s*)", numel(instance), numel(mcp), ...
                prodserver.mcp.MCPConstants.MCPMetricPrefix);
            txt = "  " + className + " of " + n + " metrics from " + from + ...
                ":" + newline + newline + counts + newline + ...
                "    " + toolSummary(mc) + newline + newline + hint;
        end

        function txt = toolSummary(mc)
        %toolSummary The tools called, with how often: MCP_<tool>_Call
        %   summed over the archives that report it. The first few, by name.
            C = prodserver.mcp.MCPConstants;
            calls = scope(mc, prodserver.mcp.metrics.Scope.Tool);
            % Only the calls: not the rejections, refusals or per-revision
            % counts, which the Tool kind includes too.
            if ~isempty(calls)
                calls = calls(endsWith([calls.name], C.MCPToolCallSuffix));
            end
            if isempty(calls)
                txt = "No tools called yet.";
                return
            end
            tools = extractBetween([calls.name], strlength(C.MCPMetricPrefix) + 1, ...
                strlength([calls.name]) - strlength(C.MCPToolCallSuffix));
            [tools, ~, which] = unique(tools(:));
            total = accumarray(which, [calls.value]');
            shown = min(numel(tools), 4);
            list = strjoin(tools(1:shown) + " " + string(total(1:shown)), ", ");
            if numel(tools) > shown
                list = list + ", ...";
            end
            txt = numel(tools) + " tool(s) called: " + list;
        end

    end
end

function tf = isKind(metrics, s)
%isKind True for each of METRICS that is of kind S, read from its name.
%   Server needs the archive too: MCP_foo_bar_Request is foo_bar's, not
%   foo's, whatever a name pattern would say.
    C = prodserver.mcp.MCPConstants;
    names = [metrics.name];
    instance = startsWith(names, "matlabprodserver_");
    framework = names == C.MCPRequestMetric;
    own = C.MCPMetricPrefix + [metrics.archive];
    server = ~framework & strlength([metrics.archive]) > 0 & ...
        (names == own + C.MCPMetricSuffix | ...
         names == own + C.MCPElapsedTimeSuffix);
    revision = "_" + digitsPattern(4) + "_" + digitsPattern(2) + ...
        "_" + digitsPattern(2);
    tool = matches(names, C.MCPMetricPrefix + wildcardPattern(1, Inf) + ...
        (C.MCPToolCallSuffix | C.MCPToolRejectedSuffix | ...
        C.MCPToolRefusedSuffix) + optionalPattern(revision));
    mcp = framework | server | tool;
    switch s
        case prodserver.mcp.metrics.Scope.All
            tf = true(size(names));
        case prodserver.mcp.metrics.Scope.Instance
            tf = instance;
        case prodserver.mcp.metrics.Scope.MCP
            tf = mcp;
        case prodserver.mcp.metrics.Scope.Framework
            tf = framework;
        case prodserver.mcp.metrics.Scope.Server
            tf = server;
        case prodserver.mcp.metrics.Scope.Tool
            tf = tool;
        case prodserver.mcp.metrics.Scope.Custom
            tf = ~instance & ~mcp;
    end
end
