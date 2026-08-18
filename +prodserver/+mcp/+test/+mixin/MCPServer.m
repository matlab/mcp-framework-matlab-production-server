classdef MCPServer < handle
%MCPServer Mock MCP Server mix-in for test classes. Calls handlers and
%encoders directly. Allows testing without starting MPS instance (and
%direct debugging of tested code).

% Copyright 2026-2026 The MathWorks, Inc.

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

        function response = handleRequest(mcp,req)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.jsonrpc.mcpDecode

            response = prodserver.mcp.internal.mcpHandler(req);
            response = prodserver.mcp.internal.decodeBody(response);

            % Wire-decode structuredContent using the tool's encoding.
            if isstruct(response) && isfield(response,'result') && ...
                    isfield(response.result,'structuredContent')
                toolEncoding = prodserver.mcp.WireEncoding.Invertible;
                body = prodserver.mcp.internal.decodeBody(req);
                if isstruct(body) && isfield(body,'params') && ...
                        isfield(body.params,'name')
                    try
                        d = load(MCPConstants.DefinitionFile);
                        sig = d.(MCPConstants.DefinitionVariable).signatures;
                        fcn = body.params.name;
                        if isfield(sig,fcn) && isfield(sig.(fcn),'encoding')
                            toolEncoding = prodserver.mcp.WireEncoding(sig.(fcn).encoding);
                        end
                    catch
                    end
                end
                sc = response.result.structuredContent;
                flds = fieldnames(sc);
                allVals = cell(1,numel(flds));
                for k = 1:numel(flds)
                    allVals{k} = sc.(flds{k});
                end
                decoded = mcpDecode(toolEncoding, allVals{:});
                for k = 1:numel(flds)
                    sc.(flds{k}) = decoded{k};
                end
                response.result.structuredContent = sc;
            end
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
            end

            import prodserver.mcp.MCPConstants
            
            req = mcp.baseRequest;
           
            req.Headers = [req.Headers; ...
                { MCPConstants.SessionId opts.sessionID} ];

            req.Path = "/"+server+"/mcp";

            if ~isempty(opts.body)
                req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                    'application/json'}];
                req.Method = "POST";  % Because there's a body
                req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(opts.body)}];
                req.Body = unicode2native(opts.body,"UTF-8");
            else
                req.Method = "GET";
            end
        end

    end
end