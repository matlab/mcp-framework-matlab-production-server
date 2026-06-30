function metrics = metrics(uri,scope,opts)
% metrics 
    arguments(Input)
        % Server address or MCP tool endpoint
        uri (1,1) string { prodserver.mcp.validation.mustBeURI }
        % Filter reported metrics by scope
        scope (1,1) prodserver.mcp.MetricsScope = prodserver.mcp.MetricsScope.MCP
        % Number of seconds to wait for HTTP requests to complete.
        opts.timeout double {prodserver.mcp.validation.mustBePositiveInteger} = 180;
        % How many times to retry HTTP requests.
        opts.retry double = 30
        % How long to wait between retries
        opts.delay double = 2
    end

    import prodserver.mcp.MetricsScope
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.MCPConstants

    metricsAPI = "/api/metrics";

    % Derive server address from input URI, which must be either an MATLAB
    % Production Server address or an MCP tool endpoint.

    uri = prodserver.mcp.io.parseURI(uri);
    metricsQuery = uri.scheme + Constants.SchemeSuffix + Constants.AuthorityPrefix;
    if strlength(uri.userInfo) > 0
        metricsQuery = metricsQuery + uri.userInfo + Constants.UserInfoSuffix;
    end
    metricsQuery = metricsQuery + uri.host;
    if prodserver.mcp.validation.istext(uri.port) 
        metricsQuery = metricsQuery + Constants.PortPrefix + uri.port;
    end

    % Add the metrics API endpoint and query the server.
    metricsQuery = metricsQuery + metricsAPI;
    webOpts = weboptions(Timeout=opts.timeout);
    result = [];
    n = 1;
    while n <= opts.retry && isempty(result)
        try
            result = webread(metricsQuery,webOpts);
        catch me
            % Often occurs because server still starting up.
            if contains(me.identifier,"ConnectionRefused") || ...
                    contains(me.message,"could not connect to server",IgnoreCase=true) || ...
                    contains(me.message,"connection refused",IgnoreCase=true)
                pause(opts.delay);
            elseif contains(me.identifier,"HTTP403") && contains(me.message,"metrics disabled",IgnoreCase=true)
                error("prodserver:mcp:MetricsDisabled", "Metrics disabled for %s. Enable metrics with the " + ...
                    "--enable-metrics property in the main_config configuration file.");
            else
                rethrow(me);
            end
        end
        n = n + 1;
    end

    if prodserver.mcp.validation.istext(result) == false
        error("prodserver:mcp:ServerUnresponsive", ...
            "The server at %s did not respond to a metrics query. " + ...
            "Check to be sure the server is running and that you have " + ...
            "permissions to access it.",uri.uri);
    end

    % Convert character result into a string array with one string per
    % line.
    result = string(splitlines(result));

    % Sometimes there's an empty line at the end.
    if strlength(result(end)) == 0
        result = result(1:end-1);
    end

    % Insist on an even number of lines.
    if mod(numel(result),2) ~= 0
        error("prodserver:mcp:UnevenMetricsReport", ...
            "Metrics report must have an even number of lines. It " + ...
            "has %d which is not an even number.", numel(result));
    end

    %    % Parse result into a structure. Each metric consists of two lines:
    %   # TYPE matlabprodserver_up_time_seconds counter
    %   matlabprodserver_up_time_seconds 46.0555
    %
    % Create structure with one field per metric. The value of each metric
    % field is a structure with fields "archive", "type" and "value".
    %
    %   m.matlabprodserver_up_time_seconds.archive = "toyToolOne_8";
    %   m.matlabprodserver_up_time_seconds.type = "counter";
    %   m.matlabprodserver_up_time_seconds.value = 46.0555;
    %
    % archive may be empty, if the metrics service does not report an
    % archive for a given metric.

    archivePattern = "{" + wildcardPattern(except="}") + "}";
    for n = 1:2:numel(result)
        nvp = split(result(n+1));
        name = nvp(1);
        archive = extract(name,archivePattern);
        name = erase(name,archive);
        if strlength(archive) > 0
            archive = extractBetween(archive,2,strlength(archive)-1);
            archive = extractBetween(archive,"archive=""","""");
        end
        value = nvp(2);
        type = split(result(n)); 
        type = type(end);
        metrics.(name).type = type;
        if strcmpi(type,"counter") || strcmpi(type,"gauge")
            value = double(value);
        end
        metrics.(name).value = value;
        metrics.(name).archive = archive;
    end

    % Filter metrics by name

    fields = fieldnames(metrics);

    switch scope
        case MetricsScope.All
            % Absolutely every metric known to the MPS instance.
            % That's what the metrics struct already contains.

        case MetricsScope.Instance
            % Only those metrics which start with matlabprodserver_
            instanceFields = startsWith(fields,"matlabprodserver_",...
                IgnoreCase=true);
            remove = instanceFields == false;
            if nnz(remove) > 0
                metrics = rmfield(metrics,fields(remove));
            end

        case MetricsScope.MCP
            % None of the instance fields
            mcpFields = startsWith(fields,"mcp_",IgnoreCase=true);
            remove = mcpFields == false;
            if nnz(remove) > 0
                metrics = rmfield(metrics,fields(remove));
            end

        case MetricsScope.Server
            % Only the fields that contain the tool server name
            serverPattern = "/" + wildcardPattern(except="/") + ...
                MCPConstants.MCP + textBoundary("end");
            serverName = extract(uri.uri,serverPattern);
            serverName = split(serverName,"/");
            serverName = serverName(2); % First string is "" because /
            serverFields = contains(fields,"_" + serverName + "_");
            remove = serverFields == false;
            if nnz(remove) > 0
                metrics = rmfield(metrics,fields(remove));
            end

        otherwise
            % This may happen if somebody adds a scope but forgets to
            % update this function.
            error("prodserver:mcp:UnhandledMetricsScope", ...
                "MetricsScope '%s' unknown.", scope);
    end


end
