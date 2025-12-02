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
        result = handleError(request,jrpc,httpCode,me);
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

function result = handleError(request,jrpc,code,ex)
    if isfield(jrpc,"jsonrpc")
        result.jsonrpc = jrpc.jsonrpc;
    else
        result.jsonrpc = "Unknown";
    end
    if isfield(request,"id")
        result.id = request.id;
    end
    % Rudimentary error location. May decide to add more detail.
    location = ex.stack(1);
    [~,file] = fileparts(location.file);
    msg = sprintf("%s:%d : %s", file, location.line, ex.message);
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

        % Find tool definition
        tools = d.(MCPConstants.DefinitionVariable).tools;
        % Cast to string because sometimes the name may be a char, which
        % don't count as uniform output.
        tName = cellfun(@(t)string(t.name),tools);

        fcn = jrpc.params.name;
        k = strcmp(tName,fcn);
        if nnz(k) > 1
            error("prodserver:mcp:AmbiguousToolName", ...
                "Multiple tools matching name '%s'. Rebuild server " + ...
                "using unambigous names.", fcn);
        end
        if nnz(k) == 0
            error("prodserver:mcp:ToolUnavailable", ...
                "Tool '%s' not available on this MCP server.", fcn);
        end

        % Only one definition matching the tool name.
        t = tools{k};
        
        % JRPC in MCP does not define argument order. So we (cleverly!)
        % insert order information into the definition. Assemble a cell
        % array with the arguments in the right order.
        sig = d.(MCPConstants.DefinitionVariable).signatures;
        in = sig.(fcn).input.name;

        % Separate optional from required arguments. First subtract ALL
        % optional arguments from full list of inputs (in). Then set
        % optional to the ACTUAL optional arguments in the tools/call
        % message.
        optional = setdiff(in,t.inputSchema.required);
        in = setdiff(in,optional,'stable');
        optional = setdiff(fieldnames(jrpc.params.arguments),...
            t.inputSchema.required);

        % All required arguments must be present.
        if ~isempty(setxor(in,t.inputSchema.required))
            error("prodserver:mcp:BadInputArguments", ...
                "Tool '%s' requires inputs '%s', but received '%s'.", ...
                fcn,strjoin(t.inputSchema.required,","), strjoin(in,","));
        end

        % Make space for all arguments
        inArgs = cell(1,numel(in)+(numel(optional)*2));
        for n = 1:numel(in)
            inArgs{n} = jrpc.params.arguments.(in{n});
        end

        % Add optional arguments to the end of the argument list as 
        % name-value pairs: use name of the argument as the name of the
        % name-value pair.
        k = numel(in) + 1;
        for n = 1:numel(optional)
            inArgs{k} = optional{n};
            inArgs{k+1} = jrpc.params.arguments.(optional{n});
            k = k + 2;
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
        r.content = cell(1,numel(out));
        for n = 1:numel(out)
            r.structuredContent.(out{n}) = outArgs{n};

            % Should not be required but some clients require non-empty
            % content, even when structuredContent has a value (looking at you,
            % Claude).
            r.content{n}.type = "text";
            r.content{n}.text = jsonencode(outArgs{n});
        end
    end

    if ~isempty(result)
        result.result = r;
    end
end

