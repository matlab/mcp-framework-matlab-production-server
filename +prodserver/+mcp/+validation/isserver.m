function [tf, isActive] = isserver(x,opts)
% isserver Is the input the address of a MATLAB Production Server?

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        x
        opts.retry double = 2
        opts.timeout double = 10
        % Seconds between health-check attempts.
        opts.delay double = 1
    end

    % Must be a string of some type
    tf = prodserver.mcp.validation.istext(x);
    if tf
        % Must be a valid URI (kind of an expensive check, but
        % authoritative).
        tf = prodserver.mcp.validation.isuri(x);
        if tf
            % Must be only the <scheme>://<authority>/ portion of a URI.
            % Trailing / is optional. HTTP requires a host (RFC 9110), so
            % the authority may not be empty, though isuri allows that.
            address = ("http" | "https") + "://" + ...
                wildcardPattern(1,Inf,Except="/") + optionalPattern("/") + ...
                textBoundary("end");
            tf = matches(x,address);
        end
    end

    if nargout == 2 
        if tf
            ping = "api/health";
            if endsWith(x,"/")
                url = x + ping;
            else
                url = x + "/" + ping;
            end
            webOpts = weboptions(Timeout=opts.timeout);

            % A server still starting up refuses the connection or answers
            % 404; both are retried. A timeout is not: TIMEOUT has already
            % been waited out once. Running out of attempts is an inactive
            % server, not an error -- including a retry budget below 1,
            % which makes no attempt at all. The loop stops at the first
            % answer (XD28). This is also deploy's health check, so the two
            % cannot apply different policies to the same server.
            result = prodserver.mcp.internal.webreadWithRetry(url, webOpts, ...
                attempts=opts.retry, delay=opts.delay, ...
                retryable=@(me) prodserver.mcp.internal.isTransientError( ...
                    me, timeout=false, status=404), ...
                accept=@(r) ~isempty(r));
            isActive = isstruct(result) && isfield(result,"status") && ...
                strcmpi(result.status,"ok");
        else
            isActive = false;
        end
    end
end