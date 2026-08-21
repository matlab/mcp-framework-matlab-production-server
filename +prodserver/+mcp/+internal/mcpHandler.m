function response = mcpHandler(request)
%mcpHandler Custom web handler for MCP JSON RPC protocol.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.getHeaderValue

    try
        data = [];
        jrpc = [];

        % Need server name for metrics. Expecting URLs to look like this:
        %   /<server>/mcp
        % Trying to extract <server> from that string. Since split will add
        % "" for /, <server> should the the 2nd element in the return
        % value from split.
        serverName = split(request.Path,Constants.URISep);
        if numel(serverName) >= 2
            serverName = serverName(2);
        else
            serverName = "";
        end
        if isempty(serverName) || strlength(serverName) == 0
            error("prodserver:mcp:InvalidServerURL", ...
                "Cannot determine server name from request URL '%s'.", ...
                request.Path);
        end

        % Record elapsed time -- this time measures overhead and tool 
        % call time.
        serverTimeMetric = MCPConstants.MCPMetricPrefix + serverName + "_ElapsedTime";
        et = tic();
        elapsed = onCleanup(@()prodserver.metrics.incrementCounter(serverTimeMetric,toc(et)));

        headers = {};
        session = getHeaderValue(MCPConstants.SessionId, request.Headers);
        if ~isempty(session)
            headers = {MCPConstants.SessionId session};
        end
    
        % Error if not present post-initialization
        protocolVersion = getHeaderValue(MCPConstants.ProtocolVersion, ...
            request.Headers);

        % Count the number of times mcpHandler is called.
        prodserver.metrics.incrementCounter(MCPConstants.MCPRequestMetric,1);

        % Record number of calls 
        serverMetric = MCPConstants.MCPMetricPrefix + serverName + "_Request";
        prodserver.metrics.incrementCounter(serverMetric,1)
        
        switch lower(request.Method)                
            case "get"
                % Don't support Server-Sent Events (SSE). 
  
                httpCode = 405;  % Nope
                httpMsg = 'Method Not Allowed';
                
                msgHeaders = {MCPConstants.SessionId session};
    
            case "post"

                jrpc = prodserver.mcp.internal.decodeBody(request);
                if isempty(protocolVersion) && isfield(jrpc,"params") 
                    if isfield(jrpc.params,"protocolVersion")
                        protocolVersion = jrpc.params.protocolVersion;
                    end
                end

                [result, httpCode, httpMsg, msgHeaders] = handlePost(jrpc);

                % Some handlers may manage the JSON-encoding themselves,
                % for their own mysterious reasons. They will indicate
                % they've done so by setting the message header
                % Content-Type to "application/json"

                ct = "";
                if ~isempty(msgHeaders)
                    ct = getHeaderValue(MCPConstants.ContentType,msgHeaders);
                end

                if strcmpi(ct,Constants.MIMETypeJSON) == false
                    if ~isempty(result)
                        data = jsonencode(result);
                    end
    
                    msgHeaders = vertcat(msgHeaders, ...
                            {MCPConstants.ContentType, ...
                            char(Constants.MIMETypeJSON)});
                else
                    data = result;
                end
    
            case "delete"
                httpCode = 204;
                httpMsg = 'No Content';
                msgHeaders = {MCPConstants.SessionId session};

                data = [];
        end
    catch me
        httpCode = 500;
        httpMsg = 'MATLAB Exception';
        result = prodserver.mcp.handler.internal.handleError(jrpc,me);
        data = jsonencode(result);
        msgHeaders = {MCPConstants.ContentType, 'application/json'};
    end

    headers = vertcat({'Server' 'Robot Preschool'}, headers, ...
        msgHeaders);
    if ~isempty(protocolVersion)
        headers = vertcat(headers, ...
            {MCPConstants.ProtocolVersion protocolVersion});
    end
    if ~isempty(data)
        body = unicode2native(data,'UTF-8');
    else
        body = uint8.empty(1,0);
    end
    response = struct( ...
        'ApiVersion',[1 0 0], ...
        'HttpCode',httpCode, ...
        'HttpMessage',httpMsg, ...
        'Headers', {headers}, ...
        'Body', body);
end


function [result, httpCode, httpMsg, msgHeaders] = handlePost(jrpc)

    mth = lower(jrpc.method);
    result = []; %#ok<NASGU>

    if strcmp(mth,"ping")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.ping(jrpc);

    elseif strcmp(mth,"initialize")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.initialize(jrpc);

    elseif contains(mth,"notifications/initialized")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.notifications.initialized(jrpc);

    elseif contains(mth,"notifications/cancelled")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.notifications.cancelled(jrpc);

    elseif contains(mth,"resources/list")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.resource.list(jrpc);

    elseif contains(mth,"resources/read")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.resource.read(jrpc);

    elseif contains(mth,"tools/list")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.tools.list(jrpc);

    elseif contains(mth,"tools/call")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.tools.call(jrpc);

    elseif endsWith(mth,"/list")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.listFallback(jrpc);
    else
        error("prodserver:mcp:UnsupportedRequest", ...
            "Invalid or unsupported MCP method %s", mth);
    end
end

