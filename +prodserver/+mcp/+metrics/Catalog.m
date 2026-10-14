classdef Catalog
% Catalog Collection of MATLAB Production Server metrics. 

% Copyright 2026 The MathWorks, Inc.

    properties (Access=protected)
        % Fields: name, type, archive, value
        metrics struct
        % Name of the server from which these metrics derive
        server
    end

    methods
        function mc = Catalog(data,uri)

            % Insist on an even number of lines.
            if mod(numel(data),2) ~= 0
                error("prodserver:mcp:UnevenMetricsReport", ...
                    "Metrics report must have an even number of lines. It " + ...
                    "has %d which is not an even number.", numel(data));
            end

            serverPattern = "/" + wildcardPattern(except="/") + ...
                prodserver.mcp.MCPConstants.MCP + textBoundary("end");
            serverName = extract(uri, serverPattern);
            serverName = split(serverName, "/");
            mc.server = serverName(2);

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
                archiveLabel = extract(mc.metrics(idx).name, archivePattern);
                mc.metrics(idx).name = erase(mc.metrics(idx).name, archiveLabel);
                if ~isempty(archiveLabel)
                    archiveLabel = extractBetween(...
                        archiveLabel, 2, strlength(archiveLabel)-1);
                    archiveLabel = extractBetween(...
                        archiveLabel, "archive=""", """");
                    mc.metrics(idx).suffix = erase(extract(archiveLabel, ...
                        suffixPattern),"_");
                    mc.metrics(idx).archive = erase(archiveLabel,suffixPattern);
                else
                    mc.metrics(idx).archive = "";
                    mc.metrics(idx).suffix = [];
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

            % All metrics matching name
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
        % Filter metrics by scope

            arguments
                mc prodserver.mcp.metrics.Catalog
                s prodserver.mcp.metrics.Scope
            end

            names = [mc.metrics.name];
            switch s
                case prodserver.mcp.metrics.Scope.All
                    metrics = mc.metrics;

                case prodserver.mcp.metrics.Scope.Instance
                    i = startsWith(names, "matlabprodserver_");
                    metrics = mc.metrics(i);

                case prodserver.mcp.metrics.Scope.MCP
                    i = startsWith(names, ...
                        prodserver.mcp.MCPConstants.MCPMetricPrefix);
                    metrics = mc.metrics(i);

                case prodserver.mcp.metrics.Scope.Tool
                    toolPattern = prodserver.mcp.MCPConstants.MCPMetricPrefix + ...
                        wildcardPattern + prodserver.mcp.MCPConstants.MCPToolCallSuffix;
                    metrics = name(mc,toolPattern);

                case prodserver.mcp.metrics.Scope.Server
                    
                    metrics = name(mc, "_" + mc.server + "_", ...
                        match="Contains");

                otherwise
                    error("prodserver:mcp:UnhandledMetricsScope", ...
                        "MetricsScope '%s' unknown.", s);
            end

        end
    end
end
