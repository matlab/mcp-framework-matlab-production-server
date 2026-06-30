function msg = encodeBody(msg)
%encodeBody Encode the message body according to the message's
%Content-Type.
%
% The message may take one of three forms: matlab.net.http.ResponseMessage, 
% matlab.net.http.RequestMessage or a MATLAB Production Server custom web 
% handler message structure. The only difference that matters here is that 
% the first two have a "Header" field, while the third has a "Headers" 
% field.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.hasField

    if hasField(msg,"Body.Data")
        data = msg.Body.Data;
        mps = false;
    elseif hasField(msg,"Body")
        data = msg.Body;
        mps = true;
    else
        data = [];
    end
    
    if ~isempty(data)
        bodyCT = string.empty;
        if hasField(msg,"Headers")
            hName = "Headers";
            bodyCT = prodserver.mcp.internal.getHeaderValue(...
                prodserver.mcp.MCPConstants.ContentType, msg.Headers);
        elseif hasField(msg,"Header")
            hName = "Header";
            if ischar(msg.Header(1).Name)
                hNameList = {msg.Header.Name};
            elseif isstring(msg.Header(1).Name)
                hNameList = [msg.Header.Name];
            end
            contentPos = matches(hNameList, ...
                prodserver.mcp.MCPConstants.ContentType);
            if ~isempty(contentPos) && nnz(contentPos) > 0
                bodyCT = msg.Header(contentPos).Value;
            end
        end

        if startsWith(bodyCT,"application/json")
            data = jsonencode(data);
            if mps
                data = unicode2native(data,"UTF-8");
            end
        elseif bodyCT == "application/octet-stream"
            data = getByteStreamFromArray(data);
        elseif startsWith(bodyCT,"text/")
            data = unicode2native(data,"UTF-8");
        else
            error("prodserver:mcp:ContentTypeRequired", ...
                "Cannot encode message body without Content-Type header.");
        end
        if iscolumn(data), data = data'; end
        if mps
            msg.Body = data;
        else
            msg.Body.Data = [];
            msg.Body.Payload = data;
        end   

        w = whos("data");
        len = w.bytes;
        msg.(hName) = prodserver.mcp.internal.setHeaderValue(msg.(hName),...
            prodserver.mcp.MCPConstants.ContentLength,{len});
    end
end