function tf = ping(endpoint,opts)
% Send a ping request to the specified endpoint. Returns true if the
% endpoint responds to the ping, false otherwise.
%
% Examples:
%
%   Assume the MCP Tool cleanSignal is deployed to
%   http://localhost:9910/cleanSignal/mcp.
%
%   tf = prodsever.mcp.ping("http://localhost:9910/cleanSignal/mcp")
%     tf = true

% Copyright 2025, The MathWorks.

    arguments 
        endpoint (1,1) string { prodserver.mcp.validation.mustBeURI }
        opts.timeout = 60
    end

    import prodserver.mcp.MCPConstants
    try
        if endsWith(endpoint,MCPConstants.MCP)
            endpoint = replace(endpoint, ...
                MCPConstants.MCP+textBoundary("end"),...
                "/"+MCPConstants.Ping);
        end
        opts = weboptions(Timeout=opts.timeout);
        response = webread(endpoint,opts);
        tf = strcmpi(response,MCPConstants.Pong);
    catch me
        tf = false;
    end
end
