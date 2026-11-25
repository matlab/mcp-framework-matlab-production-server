function response = signatureHandler(request)
%signatureHandler Custom web handler for signature requests.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.protocol.v20250618.Constants
    import prodserver.mcp.internal.getHeaderValue

    % Get session, if available, to echo it back. Only one this server
    % issued: echoed, a client-supplied value of any length goes into the
    % response headers, and past about 4 KB Production Server fails the
    % response after the request has been handled.
    session = getHeaderValue(Constants.SessionId, request.Headers);
    [~, caps, known] = prodserver.mcp.protocol.v20250618.decodeSession(session);
    if ~known
        session = string.empty;
    end

    % Only support GET and POST. OPTIONS returns an Allow header.
    mth = ["GET","POST","OPTIONS"];
    % Validate the request method
    if ~ismember(request.Method, mth)
        [code, msg] = prodserver.mcp.handler.internal.httpStatus(405);
        body = struct('error', 'Only GET and POST methods are supported.');
        % RFC 9110 §15.5.6: a 405 MUST say what is allowed (G11).
        response = prodserver.mcp.internal.prepareResponse(code, msg, ...
            body=body, sid=session, ct=prodserver.mcp.internal.Constants.MIMETypeJSON, ...
            headers={'Allow', char(strjoin(mth, ', '))});
        return;
    end
    if request.Method == "OPTIONS"
        % Handle the OPTIONS request by returning allowed methods
        allowedMethods = strjoin(mth, ', ');
        [code, msg] = prodserver.mcp.handler.internal.httpStatus(200);
        response = prodserver.mcp.internal.prepareResponse(code, msg, ...
            body=struct(), sid=session, ct=prodserver.mcp.internal.Constants.MIMETypeJSON, ...
            headers={'Allow', char(allowedMethods)});
        return;
    end

    % Body: comma-separated list of function names. Return signature of
    % each named function. If none, return all.
    fcnList = prodserver.mcp.internal.decodeBody(request);
    if isempty(fcnList)
        fcnList = ''; % Pass istext() check.
    end
    [code, msg] = prodserver.mcp.handler.internal.httpStatus(200);
    
    % If decodeBody doesn't recognize the Content-Type, it returns non-text.
    % That means the request was malformed.
    if prodserver.mcp.validation.istext(fcnList) == false
        body = sprintf("List of signatures must have text type, " + ...
            "but is %s.", class(fcnList));
        code = 400;
        msg = 'Bad Request (non-decodable body)';  % Not httpStatus: more said
        fcnList = []; % Don't pass isempty() guard
    else
        % Load the signature information from the MAT-file.
        svc = prodserver.mcp.handler.toolServices;
        signatures = svc.(MCPConstants.DefinitionVariable).signatures;

        % uri2json is for an MCP App's view: like tools/list, describe it
        % only to a client that declared MCP Apps support. The only place
        % this route can learn that is the session token, so a request
        % without a 2025-06-18 session doesn't see it.
        if isfield(signatures, MCPConstants.Uri2JsonTool) && ...
                ~supports(caps, MCPConstants.UIExtension_JSON)
            signatures = rmfield(signatures, MCPConstants.Uri2JsonTool);
        end
    end

    if ~isempty(fcnList) 
        fcnList = strtrim(split(fcnList,","));
        sigNames = fieldnames(signatures);

        % Only allow requests for signatures that exist
        % fcnList will reduce to only those functions in signatures.
        fcnList = intersect(fcnList,sigNames);

        % Since there isn't a copyfield, we invert and use rmfield
        toRemove = setdiff(fieldnames(signatures),fcnList);
        signatures = rmfield(signatures,toRemove);

        if numel(fieldnames(signatures)) == 0
            % Never return 200 with empty body for JSON clients. Since the
            % signature didn't match, 404 (not found) seems appropriate.
            body = struct();
            [code, msg] = prodserver.mcp.handler.internal.httpStatus(404);
        else
            body = signatures;
        end
    elseif code == 200
        body = signatures;
    end 

    response = prodserver.mcp.internal.prepareResponse(code,msg, ...
        body=body,sid=session,ct=prodserver.mcp.internal.Constants.MIMETypeJSON);

end
