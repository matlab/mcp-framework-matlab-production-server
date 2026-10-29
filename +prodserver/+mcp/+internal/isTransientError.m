function tf = isTransientError(me, opts)
%isTransientError Could the request that raised ME succeed if sent again?
%   TF = isTransientError(ME) is true for a failure that can change while
%   the request does not: a refused connection (the server may still be
%   starting), a timeout, or an HTTP status in Constants.RetryableStatus
%   reported by webread/webwrite as a MATLAB:webservices:HTTPnnn identifier.
%
%   The vocabulary -- which identifiers and message fragments mean "refused"
%   or "timed out" -- lives here and nowhere else. Callers differ in which
%   kinds of failure their retry policy covers, and say so with options:
%
%     connection   (true)  A refused or failed connection counts.
%     timeout      (true)  A timeout counts.
%     status       (Constants.RetryableStatus)  HTTP statuses that count.
%                  Pass [] for none.
%     serverErrors (false) Any 5xx counts. Only for a request that is safe
%                  to repeat after the server failed partway through it.
%
%   The messages of ME and of every exception in its cause chain are
%   searched: matlab.net.http reports a timeout through a cause, and the
%   top-level message may not mention it.

% Copyright 2026 The MathWorks, Inc.

    arguments
        me (1,1) MException
        opts.connection (1,1) logical = true
        opts.timeout (1,1) logical = true
        opts.status double = prodserver.mcp.internal.Constants.RetryableStatus
        opts.serverErrors (1,1) logical = false
    end

    id = string(me.identifier);
    msg = messages(me);

    tf = false;
    if opts.connection
        tf = tf || contains(id, "ConnectionRefused") || ...
            any(contains(msg, ["connection refused" "could not connect"], ...
                IgnoreCase=true));
    end
    if opts.timeout
        tf = tf || contains(id, "Timeout", IgnoreCase=true) || ...
            any(contains(msg, ["timed out" "timeout"], IgnoreCase=true));
    end
    if ~isempty(opts.status)
        tf = tf || contains(id, "HTTP" + string(opts.status(:)'));
    end
    if opts.serverErrors
        tf = tf || ~isempty(regexp(id, "HTTP5\d\d", "once"));
    end
end

function msg = messages(me)
%messages The message of ME and of every exception in its cause chain.
    msg = string(me.message);
    for k = 1:numel(me.cause)
        msg = [msg, messages(me.cause{k})]; %#ok<AGROW>
    end
end
