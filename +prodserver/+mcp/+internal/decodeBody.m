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
            if ischar(msg.Header(1).Name)
                hNameList = {msg.Header.Name};
            elseif isstring(msg.Header(1).Name)
                hNameList = [msg.Header.Name];
            end
            contentPos = matches(hNameList, MCPConstants.ContentType);
            if ~isempty(contentPos) && nnz(contentPos) > 0
                bodyCT = msg.Header(contentPos).Value;
            end
        end
        
        if bodyCT == "application/json"
            if mps
                data = native2unicode(data,"UTF-8");
            end
            data = jsondecode(data);
            if isstruct(data)
                % For tools/call requests, wire-decode MATLAB values in
                % params.arguments.
                if isfield(data,'method') && strcmp(data.method,'tools/call') && ...
                        isfield(data,'params') && isfield(data.params,'arguments')
                    args = data.params.arguments;
                    flds = fieldnames(args);
                    for k = 1:numel(flds)
                        args.(flds{k}) = prodserver.mcp.jsonrpc.mcpWireDecodeValue( ...
                            args.(flds{k}));
                    end
                    data.params.arguments = args;
                end
                % For tools/call responses, wire-decode MATLAB values in
                % structuredContent.
                if isfield(data,'result')
                    r = data.result;
                    if isfield(r,'structuredContent')
                        flds = fieldnames(r.structuredContent);
                        for k = 1:numel(flds)
                            r.structuredContent.(flds{k}) = ...
                                prodserver.mcp.jsonrpc.mcpWireDecodeValue( ...
                                    r.structuredContent.(flds{k}));
                        end
                    end
                    data.result = r;
                end
            end
        elseif bodyCT == "application/octet-stream"
            data = getArrayFromByteStream(data);
        elseif startsWith(bodyCT,"text/")
            data = native2unicode(data,"UTF-8");
        end
    else
        data = struct.empty;
    end
end