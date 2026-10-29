classdef tPrepareResponse < matlab.unittest.TestCase
% Test the prepareResponse internal function, which builds the responses of
% the non-MCP handlers: /ping and /signature.

% Copyright 2026 The MathWorks, Inc.

    methods (Access = private)

        function verifyHeaderShape(test, response)
        % No Content-Length (Production Server sends its own, so ours went out
        % as a second one -- XD17), no repeated header, and Content-Type
        % exactly when there is a body (XD27).
            import prodserver.mcp.MCPConstants
            names = lower(string(response.Headers(:,1)));
            test.verifyFalse(any(names == lower(MCPConstants.ContentLength)), ...
                "The handler must not set Content-Length");
            test.verifyEqual(numel(unique(names)), numel(names), ...
                "No header may repeat");
            hasBody = isfield(response, "Body") && ~isempty(response.Body);
            test.verifyEqual(any(names == lower(MCPConstants.ContentType)), ...
                hasBody, "Content-Type if and only if there is a body");
            test.verifyEqual(prodserver.mcp.internal.getHeaderValue( ...
                'Server', response.Headers), MCPConstants.ServerHeader);
        end

    end

    methods(Test)

        function pingResponse(test)
            % Used to assert Content-Length equal to the body's size. That
            % header was the duplicate.
            data = prodserver.mcp.MCPConstants.Pong;
            contentType = 'text/plain';
            response = prodserver.mcp.internal.prepareResponse(200,'OK',...
                ct=contentType,body=data);

            test.verifyHeaderShape(response);
            test.verifyEqual(prodserver.mcp.internal.getHeaderValue(...
                prodserver.mcp.MCPConstants.ContentType,response.Headers), ...
                contentType);
            test.verifyEqual(response.Body, unicode2native(char(data),"UTF-8"));
        end

        function jsonResponse(test)
            response = prodserver.mcp.internal.prepareResponse(200,'OK',...
                ct='application/json',body=struct('a',1));
            test.verifyHeaderShape(response);
            test.verifyEqual(jsondecode(native2unicode(response.Body,"UTF-8")), ...
                struct('a',1));
        end

        function noBodyMeansNoContentType(test)
            % A content type was sent even with nothing for it to describe.
            response = prodserver.mcp.internal.prepareResponse(204, ...
                'No Content', ct='application/json');
            test.verifyHeaderShape(response);
        end

        function extraHeadersAndSessionSurvive(test)
            response = prodserver.mcp.internal.prepareResponse(405, ...
                'Method Not Allowed', ct='application/json', ...
                body=struct('error','no'), sid="abc", ...
                headers={'Allow', 'GET, POST'});
            test.verifyHeaderShape(response);
            test.verifyEqual(prodserver.mcp.internal.getHeaderValue( ...
                'Allow', response.Headers), 'GET, POST');
            test.verifyEqual(prodserver.mcp.internal.getHeaderValue( ...
                prodserver.mcp.protocol.v20250618.Constants.SessionId, ...
                response.Headers), 'abc');
        end
    end
end
