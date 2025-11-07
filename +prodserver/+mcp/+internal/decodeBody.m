function data = decodeBody(msg)
%decodeBody Decode the msg.Body -- the Data or Payload field according to 
%the Content-Type of the message.
%
% The message may take one of three forms: matlab.net.http.ResponseMessage, 
% matlab.net.http.RequestMessage or a MATLAB Production Server custom web 
% handler message structure. The only difference that matters here is that 
% the first two have a "Header" field, while the third has a "Headers" 
% field.

% Copyright (c) 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants

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
        bodyCT = string.empty;
        if hasField(msg,"Headers")
            bodyCT = prodserver.mcp.internal.getHeaderValue(...
                MCPConstants.ContentType,msg.Headers);
        elseif hasField(msg,"Header")
            contentPos = matches([msg.Header.Name], ...
                MCPConstants.ContentType);
            if ~isempty(contentPos) 
                bodyCT = msg.Header(contentPos).Value;
            end
        end
        
        if bodyCT == "application/json"
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