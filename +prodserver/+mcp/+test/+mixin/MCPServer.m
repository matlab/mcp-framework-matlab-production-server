classdef MCPServer < handle
%MCPServer Mock MCP Server mix-in for test classes. Calls handlers and
%encoders directly. Allows testing without starting MPS instance (and
%direct debugging of tested code).

% Copyright 2026 The MathWorks, Inc.

    properties
        baseRequest
    end
    
    methods
        function mcp = MCPServer()
            mcp.baseRequest = struct(...
                'ApiVersion',[1 0 0], ...
                'Headers', {...
                {'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)';}}); 
        end

        function response = handleRequest(mcp,req) %#ok<INUSL>
            response = prodserver.mcp.internal.mcpHandler(req);
            response = prodserver.mcp.internal.decodeBody(response);
            response = prodserver.mcp.test.decodeStructuredContent(...
                req, response);
        end

        function body = jsonToolCall(mcp,tool,id,def,sig,varargin)
            body = prodserver.mcp.jsonrpc.toolsCall(tool,id,def,sig,varargin{:});
            body = jsonencode(body);
        end

        function req = mcpRequest(mcp,server,opts)
            arguments
                mcp prodserver.mcp.test.mixin.MCPServer
                server string
                opts.body = []
                opts.sessionID string = matlab.lang.internal.uuid
                opts.protocol string = prodserver.mcp.protocol.v20250618.Constants.Version
            end

            import prodserver.mcp.MCPConstants

            req = mcp.baseRequest;
            body = opts.body;

            if opts.protocol == prodserver.mcp.protocol.v20250618.Constants.Version
                % The caller's session id, not protocolEnvelope's fresh one.
                req.Headers = [req.Headers; ...
                    { prodserver.mcp.protocol.v20250618.Constants.SessionId ...
                      opts.sessionID} ];
            elseif ~isempty(body)
                [rows, s] = prodserver.mcp.test.protocolEnvelope( ...
                    opts.protocol, jsondecode(body));
                body = jsonencode(s);
                req.Headers = [req.Headers; rows];
            else
                req.Headers = [req.Headers; ...
                    {MCPConstants.ProtocolVersion, char(opts.protocol)}];
            end

            req.Path = "/" + server + prodserver.mcp.MCPConstants.MCP;

            if ~isempty(body)
                req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                    char(prodserver.mcp.internal.Constants.MIMETypeJSON)}];
                req.Method = "POST";  % Because there's a body
                % Content-Length counts bytes, not characters.
                req.Body = unicode2native(body,"UTF-8");
                req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(req.Body)}];
            else
                req.Method = "GET";
            end
        end

    end
end