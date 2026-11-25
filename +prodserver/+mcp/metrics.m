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
        % How many times to resend the archive check after Production
        % Server's 404, as list, call, read and exist do.
        opts.retry double {mustBePositive} = ...
            prodserver.mcp.internal.Constants.ArchiveRetry
        % How long to wait between retries
        opts.delay double {mustBePositive} = ...
            prodserver.mcp.internal.Constants.ArchiveDelay
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
    %
    % Through sendRequest, as for list, call, read and exist: Production
    % Server answers 404 alike for an archive it doesn't have and one it is
    % still deploying, so the 404 is waited out, with the same warning,
    % before UnknownArchive. A refused connection or a timeout is resent
    % once, and then the server is unresponsive.
    archive = prodserver.mcp.internal.archiveFromEndpoint(uri.uri);
    if strlength(archive) > 0
        ping = matlab.net.URI(metricsQuery + "/" + archive + "/ping");
        try
            response = prodserver.mcp.internal.sendRequest( ...
                matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET), ping, ...
                timeout=opts.timeout, retry=opts.retry, delay=opts.delay, ...
                label="ping", repeatable=true);
        catch me
            if me.identifier == "prodserver:mcp:RequestTimeout" || ...
                    prodserver.mcp.internal.isTransientError(me, status=[])
                serverUnresponsive(uri.uri);
            end
            rethrow(me);
        end
        if isempty(response.Body) || isempty(response.Body.Data)
            serverUnresponsive(uri.uri);
        end
    end

    % Add the metrics API endpoint and query the server.
    metricsQuery = metricsQuery + metricsAPI;
    % A refused connection is resent once, as list, call, read and exist
    % resend one: the server may be starting. A timeout isn't resent: the
    % timeout is long, and a server that took that long would likely take
    % as long again. Either, at the end, means the server is unresponsive.
    % Anything else is the server's answer.
    webOpts = weboptions(Timeout=opts.timeout);
    try
        [result, lastError] = prodserver.mcp.internal.webreadWithRetry(metricsQuery, ...
            webOpts, attempts=2, delay=opts.delay, ...
            retryable=@(me) prodserver.mcp.internal.isTransientError(me, ...
                timeout=false, status=[]), ...
            accept=@(r) ~isempty(r));
    catch me
        if contains(me.identifier,"HTTP403") && contains(me.message,"metrics disabled",IgnoreCase=true)
            error("prodserver:mcp:MetricsDisabled", "Metrics disabled for %s. Enable metrics with the " + ...
                "--enable-metrics property in the main_config configuration file.", prodserver.mcp.io.redactURI(uri.uri));
        end
        % A timeout, which isn't resent. Not an HTTP status, though its
        % text may say "Timeout": a proxy's 504 Gateway Timeout or a 408
        % Request Timeout is the server's answer, which came at once.
        if ~startsWith(me.identifier, "MATLAB:webservices:HTTP") && ...
                prodserver.mcp.internal.isTransientError(me, connection=false, status=[])
            serverUnresponsive(uri.uri, sprintf("No answer came " + ...
                "within the %g second timeout.", opts.timeout));
        end
        % Anything else is MATLAB's own error, an HTTP status or a host
        % that can't be found, raised again with the same identifier. Its
        % message quotes the address as sent, user information included,
        % so it is redacted, as every client function's is.
        err = prodserver.mcp.internal.redactedError(me);
        if strlength(me.identifier) == 0
            error("%s", err.message);
        end
        throw(err);
    end

    if prodserver.mcp.validation.istext(result) == false
        if ~isempty(lastError)
            serverUnresponsive(uri.uri, "The connection was refused.");
        end
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

function serverUnresponsive(address, why)
    arguments
        address
        why string = ""
    end
    if strlength(why) > 0
        why = " " + why;
    end
    error("prodserver:mcp:ServerUnresponsive", ...
        "The server at %s did not respond to a metrics query.%s " + ...
        "Check to be sure the server is running and that you have " + ...
        "permissions to access it.", prodserver.mcp.io.redactURI(address), why);
end
