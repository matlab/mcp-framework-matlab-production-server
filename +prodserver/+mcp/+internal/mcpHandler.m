function response = mcpHandler(request)
%mcpHandler Custom web handler for MCP JSON RPC protocol.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.getHeaderValue

    try
        data = [];
        headers = {};
        session = getHeaderValue(MCPConstants.SessionId, request.Headers);
        if ~isempty(session)
            headers = {MCPConstants.SessionId session};
        end
    
        % Error if not present post-initialization
        protocolVersion = getHeaderValue(MCPConstants.ProtocolVersion, ...
            request.Headers);

        jrpc = [];
        
        switch lower(request.Method)                
            case "get"
                % Don't support Server-Sent Events (SSE). 
  
                httpCode = 405;  % Nope
                httpMsg = 'Method Not Allowed';
                
                msgHeaders = {MCPConstants.SessionId session};
    
            case "post"

                jsonStr = native2unicode(request.Body,'UTF-8');
                jrpc = jsondecode(jsonStr);
                if isempty(protocolVersion) && isfield(jrpc,"params") 
                    if isfield(jrpc.params,"protocolVersion")
                        protocolVersion = jrpc.params.protocolVersion;
                    end
                end

                [result, httpCode, httpMsg, msgHeaders] = handlePost(jrpc);
                if ~isempty(result)
                    data = jsonencode(result,PrettyPrint=true);
                end

                msgHeaders = vertcat(msgHeaders, ...
                        {MCPConstants.ContentType, 'application/json'});
    
            case "delete"
                httpCode = 204;
                httpMsg = 'No Content';
                msgHeaders = {MCPConstants.SessionId session};

                data = [];
        end
    catch me
        httpCode = 500;
        httpMsg = 'MATLAB Exception';
        result = handleError(request,jrpc,httpCode,me.message);
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

function result = handleError(request,jrpc,code,msg)
    if isfield(jrpc,"jsonrpc")
        result.jsonrpc = jrpc.jsonrpc;
    else
        result.jsonrpc = "Unknown";
    end
    if isfield(request,"id")
        result.id = request.id;
    end
    result.error.code = code;
    result.error.message = msg;
end

function [result, httpCode, httpMsg, msgHeaders] = handlePost(jrpc)

    import prodserver.mcp.MCPConstants

    mth = lower(jrpc.method);
    result.jsonrpc = jrpc.jsonrpc;

    % Assume the best
    httpCode = 200;
    httpMsg = 'OK';

    msgHeaders = {};

    % Default return is empty structure.
    r = struct();

    if strcmp(mth,"ping")
        result.id = jrpc.id;

    elseif strcmp(mth,"initialize")
        result.id = jrpc.id;
        if isfield(jrpc,"params")
            if isfield(jrpc.params,"capabilities")
                jrpc.params.capabilities
            end
        end

        protocolVersion = jrpc.params.protocolVersion;
        r.capabilities.tools.listChanged = true;
        session = matlab.lang.internal.uuid;
        r.protocolVersion = protocolVersion;
        r.serverInfo.name = "MATLAB Production Server";
        if contains(protocolVersion,"2024") == false
            r.serverInfo.title = "Prototype MCP Server";
        end
        r.serverInfo.version = "1.0.0";

        % All header data must be char, not string.
        msgHeaders = vertcat(msgHeaders, ...
            { MCPConstants.SessionId char(session); ...
              MCPConstants.ProtocolVersion protocolVersion });

    elseif contains(mth,"notifications/initialized")
        httpCode = 202;
        httpMsg = 'Accepted';
        % No response at all from this notification.
        result = [];

    elseif contains(mth,"notifications/cancelled")
        httpCode = 202;
        httpMsg = 'Accepted';
        % Log the reason -- if jrpc.params.reason exists.
        if isfield(jrpc,"params") && isfield(jrpc.params,"reason")
            if isfield(jrpc.params,"requestId")
                id = string(jrpc.params.requestId);
            else
                id = "(unknown)";
            end
            fprintf(1,"Request %s cancelled: %s\n",id, jrpc.params.reason);
        end
        % No response at all from this notification.
        result = [];

    elseif contains(mth,"tools/list")
        result.id = jrpc.id;

        d = load(MCPConstants.DefinitionFile);
        r.tools = d.(MCPConstants.DefinitionVariable).tools;
        % Must be returned as an array in JSON. And since it's a structure,
        % we can force JSON to treat it as an array only by embedding
        % scalar structures in a cell array.
        if iscell(r.tools) == false
            r.tools = { r.tools };
        end

    elseif endsWith(mth,"/list")
        result.id = jrpc.id;
        httpCode = 204;
        httpMsg = 'No Content';

    elseif contains(mth,"tools/call")

        result.id = jrpc.id;
        d = load(MCPConstants.DefinitionFile);
        % TODO: use for argument validation?
        tools = d.(MCPConstants.DefinitionVariable).tools;
        fcn = jrpc.params.name;

        % JRPC in MCP does not define argument order. So we (cleverly!)
        % insert order information into the definition. Assemble a cell
        % array with the arguments in the right order.
        sig = d.(MCPConstants.DefinitionVariable).signatures;
        in = sig.(fcn).input.name;
        inArgs = cell(1,numel(in));
        for n = 1:numel(in)
            inArgs{n} = jrpc.params.arguments.(in{n});
        end

        % Create a cell array large enough for all the outputs. TODO:
        % manage required / optional outputs. Unclear how MCP requests
        % number of outputs.
        out = sig.(fcn).output.name;
        outArgs = cell(1,numel(out));

        % Call the tool.
        [outArgs{:}] = feval(sig.(fcn).function, inArgs{:});
        
        % Extract tool results from cell array and write them to structure
        % (which will be JSON-encoded). outArgs and out define the order,
        % which structuredContent does not care about.
        for n = 1:numel(out)
            r.structuredContent.(out{n}) = outArgs{n};
        end

        % Should not be required but some clients apparently don't
        % implement the protocol correctly.
        r.content = {};
    end

    if ~isempty(result)
        result.result = r;
    end
end

