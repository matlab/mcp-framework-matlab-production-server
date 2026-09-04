function response = signatureHandler(request)
%signatureHandler Custom web handler for signature requests.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.getHeaderValue

    % Get session, if available.
    session = getHeaderValue(MCPConstants.SessionId, request.Headers);

    % Only support GET and POST. OPTIONS returns an Allow header.
    mth = ["GET","POST","OPTIONS"];
    % Validate the request method
    if ~ismember(request.Method, mth)
        code = 405; % Method Not Allowed
        msg = 'Method Not Allowed';
        body = struct('error', 'Only GET and POST methods are supported.');
        response = prodserver.mcp.internal.prepareResponse(code, msg, ...
            body=body, sid=session, ct="application/json");
        return;
    end
    if request.Method == "OPTIONS"
        % Handle the OPTIONS request by returning allowed methods
        allowedMethods = strjoin(mth, ', ');
        code = 200;
        msg = 'OK';
        response = prodserver.mcp.internal.prepareResponse(code, msg, ...
            body=struct(), sid=session, ct="application/json", ...
            headers={'Allow', char(allowedMethods)});
        return;
    end

    % Body: comma-separated list of function names. Return signature of
    % each named function. If none, return all.
    fcnList = prodserver.mcp.internal.decodeBody(request);
    if isempty(fcnList)
        fcnList = ''; % Pass istext() check.
    end
    code = 200;
    msg = 'OK';
    
    % If decodeBody doesn't recognize the Content-Type, it returns non-text.
    % That means the request was malformed.
    if prodserver.mcp.validation.istext(fcnList) == false
        body = sprintf("List of signatures must have text type, " + ...
            "but is %s.", class(fcnList));
        code = 400;
        msg = 'Bad Request (non-decodable body)';
        fcnList = []; % Don't pass isempty() guard
    else
        % Load the signature information from the MAT-file.
        svc = prodserver.mcp.handler.toolServices;
        signatures = svc.(MCPConstants.DefinitionVariable).signatures;
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
            code = 404;
            msg = 'Not Found';
        else
            body = signatures;
        end
    elseif code == 200
        body = signatures;
    end 

    response = prodserver.mcp.internal.prepareResponse(code,msg, ...
        body=body,sid=session,ct="application/json");

end