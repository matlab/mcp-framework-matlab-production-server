function response = signatureHandler(request)
%signatureHandler Custom web handler for signature requests.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.getHeaderValue

    % Body: comma-separated list of function names. Return signature of
    % each named function. If none, return all.
    fcnList = prodserver.mcp.internal.decodeBody(request);

    % Load the signature information from the MAT-file.
    d = load(MCPConstants.DefinitionFile);
    signatures = d.(MCPConstants.DefinitionVariable).signatures;
    if ~isempty(fcnList)
        if prodserver.mcp.validation.istext(fcnList) == false
            error("prodserver:mcp:InvalidSignatureListType", ...
                "List of signatures must have text type, but is %s.", ...
                class(fcnList));
        end
        fcnList = strtrim(split(fcnList,","));
        sigNames = fieldnames(signatures);

        % Only allow requests for signatures that exist
        % fcnList will reduce to only those functions in signatures.
        fcnList = intersect(fcnList,sigNames);

        % Since there isn't a copyfield, we invert and use rmfield
        toRemove = setdiff(fieldnames(signatures),fcnList);
        signatures = rmfield(signatures,toRemove);
        % Somehow, "struct with no fields" is not empty, so make it empty.
        if numel(fieldnames(signatures)) == 0
            signatures = struct.empty;
        end
    end

    code = 200;
    msg = 'OK';
    session = getHeaderValue(MCPConstants.SessionId, request.Headers);
    response = prodserver.mcp.internal.prepareResponse(code,msg, ...
        body=signatures,sid=session,ct="application/json");

end