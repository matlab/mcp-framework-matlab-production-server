function response = pingHandler(request)
%pingHandler Accept <archive>/ping and return 'pong'. Makes sure the server
%is awake and responsive.

% Copyright 2025, The MathWorks, Inc.

    data = prodserver.mcp.MCPConstants.Pong;

    response = prodserver.mcp.internal.prepareResponse(200,'OK',...
        ct="text/plain",body=data);
    
end