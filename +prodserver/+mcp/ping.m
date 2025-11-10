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
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 3
        opts.delay double {mustBePositive} = 2
    end

    import prodserver.mcp.MCPConstants
    tf = false;
    try
        if endsWith(endpoint,MCPConstants.MCP)
            endpoint = replace(endpoint, ...
                MCPConstants.MCP+textBoundary("end"),...
                "/"+MCPConstants.Ping);
        end
        tries = 0;
        while tf == false && tries <= opts.retry
            try 
                opts = weboptions(Timeout=opts.timeout);
                response = webread(endpoint,opts);
                tf = strcmpi(response,MCPConstants.Pong);
            catch me
                % Allow retry on HTTP / web service errors. All others are
                % immediately fatal.
                if contains(me.identifier,"MATLAB:webservices")
                    tries = opts.retry + 1;
                    tf = false;
                end
            end
            tries = tries + 1;
            if tf == false && tries <= opts.retry
                pause(opts.delay);
            end
        end

    catch me
        tf = false;
    end
end
