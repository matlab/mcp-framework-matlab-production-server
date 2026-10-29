function tf = ping(endpoint,opts)
% Send a ping request to the specified endpoint. Returns true if the
% endpoint responds to the ping, false otherwise.
%
% Examples:
%
%   Assume the MCP Tool cleanSignal is deployed to
%   http://localhost:9910/cleanSignal/mcp.
%
%   tf = prodserver.mcp.ping("http://localhost:9910/cleanSignal/mcp")
%     tf = true
%
% This is the framework's own GET /<archive>/ping, not the MCP "ping"
% method. A refused connection, a timeout or a 404 (an archive still being
% unpacked) is retried up to RETRY times, DELAY seconds apart, so a dead
% endpoint takes about RETRY*DELAY seconds to report false. Any other
% failure is final at once.

% Copyright 2022-2026 The MathWorks, Inc.

    arguments 
        endpoint (1,1) string { prodserver.mcp.validation.mustBeURI }
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 30
        opts.delay double {mustBePositive} = 2
    end

    import prodserver.mcp.MCPConstants
    try
        if endsWith(endpoint,MCPConstants.MCP)
            endpoint = replace(endpoint, ...
                MCPConstants.MCP+textBoundary("end"),...
                "/"+MCPConstants.Ping);
        end
        % webOpts, not opts: overwriting opts with the weboptions made the
        % first opts.retry below throw, and the outer catch turned that into
        % false, so ping never retried at all (ND2).
        webOpts = weboptions(Timeout=opts.timeout);
        % RETRY counts retries, so the first attempt is extra. Any answer
        % ends the loop, pong or not. A retried failure that never stops
        % leaves an empty response: false, like every other failure.
        response = prodserver.mcp.internal.webreadWithRetry(endpoint, ...
            webOpts, attempts=opts.retry+1, delay=opts.delay, ...
            retryable=@worthRetrying);
        tf = ~isempty(response) && strcmpi(response,MCPConstants.Pong);

    catch me
        tf = false;
    end
end


function tf = worthRetrying(me)
%worthRetrying Could the ping succeed if sent again? Only when the server
%   isn't listening yet, didn't answer in time, or hasn't finished unpacking
%   the archive.
    tf = prodserver.mcp.internal.isTransientError(me, status=404);
end
