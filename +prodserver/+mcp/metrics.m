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

    % An MCP endpoint names an archive. The catalog holds every metric on
    % the instance, so for an archive the server doesn't have it would
    % still look like an answer. Ask the archive's /ping route first: it
    % counts nothing, unlike an MCP request, which would change the very
    % metrics being read.
    archive = prodserver.mcp.internal.archiveFromEndpoint(uri.uri);
    if strlength(archive) > 0
        pingURL= metricsQuery + "/" + archive + "/ping";
        try
            pong = prodserver.mcp.internal.webreadWithRetry( ...
                pingURL, weboptions(Timeout=opts.timeout), ...
                attempts=opts.retry, delay=opts.delay, ...
                retryable=@(me) prodserver.mcp.internal.isTransientError(me, ...
                    timeout=false, status=[]), ...
                accept=@(r) ~isempty(r));
        catch me
            if contains(me.identifier, "HTTP404")
                error("prodserver:mcp:UnknownArchive", ...
                    "No MCP archive named '%s' at %s. Check the endpoint, " + ...
                    "or list the server's archives.", archive, metricsQuery);
            end
            rethrow(me);
        end
        if isempty(pong)
            serverUnresponsive(uri.uri);
        end
    end

    % Add the metrics API endpoint and query the server.
    metricsQuery = metricsQuery + metricsAPI;
    % A refused connection often means the server is still starting up, so
    % it is retried. Anything else is the server's answer.
    webOpts = weboptions(Timeout=opts.timeout);
    try
        result = prodserver.mcp.internal.webreadWithRetry(metricsQuery, ...
            webOpts, attempts=opts.retry, delay=opts.delay, ...
            retryable=@(me) prodserver.mcp.internal.isTransientError(me, ...
                timeout=false, status=[]), ...
            accept=@(r) ~isempty(r));
    catch me
        if contains(me.identifier,"HTTP403") && contains(me.message,"metrics disabled",IgnoreCase=true)
            error("prodserver:mcp:MetricsDisabled", "Metrics disabled for %s. Enable metrics with the " + ...
                "--enable-metrics property in the main_config configuration file.", uri.uri);
        end
        rethrow(me);
    end

    if prodserver.mcp.validation.istext(result) == false
        serverUnresponsive(uri.uri);
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

function serverUnresponsive(address)
    error("prodserver:mcp:ServerUnresponsive", ...
        "The server at %s did not respond to a metrics query. " + ...
        "Check to be sure the server is running and that you have " + ...
        "permissions to access it.", address);
end
