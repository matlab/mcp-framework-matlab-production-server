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

            % The body itself is still encoded and still the right length --
            % that is what is actually being relied on here.
            encData = unicode2native(data,"UTF-8");
            test.verifyEqual(response.Body,encData);

            % But the length is not announced. MPS frames every response it
            % sends from a custom web handler, so a Content-Length set here
            % arrives at the client as a second copy of the header: measured on
            % R2026b, GET /<archive>/ping emitted "Content-Length: 4" twice
            % while this function was still setting it. The two copies agreed,
            % which is why nothing ever broke and why only a live probe found
            % it.
            value = prodserver.mcp.internal.getHeaderValue(...
                prodserver.mcp.MCPConstants.ContentLength,response.Headers);
            test.verifyEmpty(value, ...
                "prepareResponse must leave Content-Length to MPS, but set " + ...
                "it to '" + string(value) + "'");
        end
    end
end
