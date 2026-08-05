classdef Catalog
% Catalog Collection of MATLAB Production Server metrics. 

% Copyright 2026, The MathWorks, Inc.

    properties (Access=protected)
        % Fields: name, type, archive, value
        metrics struct
    end

    methods
        function mc = Catalog(data)

            % Insist on an even number of lines.
            if mod(numel(data),2) ~= 0
                error("prodserver:mcp:UnevenMetricsReport", ...
                    "Metrics report must have an even number of lines. It " + ...
                    "has %d which is not an even number.", numel(data));
            end

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
            % Create structure array with fields "name", "archive", "type" 
            % and "value".
            %
            %   name = "matlabprodserver_up_time_seconds";
            %   archive = "";
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
                "archive", void, "value", void);

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
                    mc.metrics(idx).archive = erase(archiveLabel, suffixPattern);
                else
                    mc.metrics(idx).archive = "";
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

        function metrics = name(mc, n, opts)
        %name All metrics of a given name.
        %
        %  metrics = name(catalog, n) returns a structure array with fields
        %     "name", "type", "archive", "value" containing all the metrics
        %     with name n.

            arguments
                mc prodserver.mcp.metrics.Catalog
                n string { mustBeNonempty }
                opts.match prodserver.mcp.metrics.Match = "Exact"
            end

            list = [ mc.metrics.name ];
            switch opts.match
                case "Exact"
                    i = strcmp(list,n);
                case "Contains"
                    i = contains(list,n);
            end
            metrics = mc.metrics(i);
        end

        function metrics = archive(mc, a, opts)
        %archive All metrics from a given archive.
        %  metrics = archive(catalog, a) returns a structure array with 
        %     fields "name", "type", "archive", "value" containing all the 
        %     metrics from archive a. 

            arguments
                mc prodserver.mcp.metrics.Catalog
                a string
                opts.match prodserver.mcp.metrics.Match = "Exact"
            end

            list = [ mc.metrics.archive ];
            switch opts.match
                case "Exact"
                    i = strcmp(list,a);
                case "Contains"
                    i = contains(list,a);
            end
            metrics = mc.metrics(i);
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

            list = [ mc.metrics.type ];
            i = strcmp(list, lower(string(t)));
            metrics = mc.metrics(i);
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

                case prodserver.mcp.metrics.Scope.Server
                    serverPattern = "/" + wildcardPattern(except="/") + ...
                        prodserver.mcp.MCPConstants.MCP + textBoundary("end");
                    serverName = extract(uri.uri, serverPattern);
                    serverName = split(serverName, "/");
                    serverName = serverName(2);
                    metrics = name(mc, "_" + serverName + "_", ...
                        match="Contains");

                otherwise
                    error("prodserver:mcp:UnhandledMetricsScope", ...
                        "MetricsScope '%s' unknown.", s);
            end

        end
    end
end
