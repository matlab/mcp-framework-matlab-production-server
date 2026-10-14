function data = decodeBody(msg)
%decodeBody Decode the msg.Body -- the Data or Payload field according to
%the Content-Type of the message.
%
% The message may take one of three forms: matlab.net.http.ResponseMessage,
% matlab.net.http.RequestMessage or a MATLAB Production Server custom web
% handler message structure. The only difference that matters here is that
% the first two have a "Header" field, while the third has a "Headers"
% field.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants

    if hasField(msg,"Body.Payload") && ~isempty(msg.Body.Payload)
        data = msg.Body.Payload;
        mps = false;
    elseif hasField(msg,"Body.Data")
        data = msg.Body.Data;
        mps = false;
    elseif hasField(msg,"Body")
        data = msg.Body;
        mps = true;
    else
        data = [];
    end

    if ~isempty(data)
        % Header names are case-insensitive, and getHeaderValue matches them
        % that way for both the MPS Nx2 cell array and a HeaderField array.
        bodyCT = [];
        if hasField(msg,"Headers")
            bodyCT = prodserver.mcp.internal.getHeaderValue(...
                MCPConstants.ContentType,msg.Headers);
        elseif hasField(msg,"Header")
            bodyCT = prodserver.mcp.internal.getHeaderValue(...
                MCPConstants.ContentType,msg.Header);
        end

        % An absent Content-Type is not a malformed one. JSON is the only
        % request body this transport accepts, so an unstated type is read as
        % the one type there is. That matches how an absent Accept header is
        % treated as */* rather than refused: a header the client did not send
        % is a question it did not answer, not a wrong answer.
        %
        % A stated type is compared by its bare media type: case-insensitive
        % and with parameters removed, so "Application/JSON; charset=utf-8" is
        % JSON. The charset parameter is not consulted. RFC 8259 requires JSON
        % exchanged between systems to be UTF-8, and application/json defines
        % no charset parameter, so UTF-8 is the only reading there is.
        if isempty(bodyCT)
            bodyCT = string(Constants.MIMETypeJSON);
        else
            bodyCT = prodserver.mcp.internal.mediaType(bodyCT);
        end

        if bodyCT == Constants.MIMETypeJSON
            if mps
                data = native2unicode(data,"UTF-8");
            end
            data = jsondecode(data);
        elseif bodyCT == "application/octet-stream"
            data = getArrayFromByteStream(data);
        elseif startsWith(bodyCT,"text/")
            data = native2unicode(data,"UTF-8");
        end
    else
        data = struct.empty;
    end
end