function catalog = metrics(uri,opts)
% metrics Retrieve metrics from MATLAB Production Server instance at URI.
%
%    catalog = metrics(URI) returns the metrics recorded by the
%    MATLAB Production Server at URI.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % Server address or MCP tool endpoint
        uri (1,1) string { prodserver.mcp.validation.mustBeURI }
        % Number of seconds to wait for HTTP requests to complete.
        opts.timeout double {prodserver.mcp.validation.mustBePositiveInteger} = 180;
        % How many times to retry HTTP requests.
        opts.retry double = 30
        % How long to wait between retries
        opts.delay double = 2
    end

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

    catalog = prodserver.mcp.metrics.Catalog(result,uri.uri);

end
