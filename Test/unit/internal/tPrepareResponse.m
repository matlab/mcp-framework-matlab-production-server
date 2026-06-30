classdef tPrepareResponse < matlab.unittest.TestCase
% Test the prepareResponse internal function

% Copyright 2026 The MathWorks, Inc.

    methods(Test)

        function pingResponse(test)

            data = prodserver.mcp.MCPConstants.Pong;

            code = 200;
            msg = 'OK';
            contentType = 'text/plain';
            response = prodserver.mcp.internal.prepareResponse(code,msg,...
                ct=contentType,body=data);

            value = prodserver.mcp.internal.getHeaderValue(...
                prodserver.mcp.MCPConstants.ContentType,response.Headers);
            test.verifyEqual(value,contentType);

            value = prodserver.mcp.internal.getHeaderValue(...
                prodserver.mcp.MCPConstants.ContentLength,response.Headers);
            encData = jsonencode(data);
            encData = unicode2native(data,"UTF-8");
            w = whos("encData");
            test.verifyEqual(value,w.bytes);
        end
    end
end
