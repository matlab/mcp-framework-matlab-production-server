function response = sendRequest(request,uri,opts)
% sendRequest Send an HTTP request to a URL. Optional arguments to control
% timeout and retry behavior.

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
        request (1,1) matlab.net.http.RequestMessage
        uri (1,1) matlab.net.URI
        opts.label string = ""
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 3
        opts.delay double {mustBePositive} = 2
    end

    % Statuses worth a second attempt: the same request may well succeed if
    % we wait.
    %
    % 404 is the load-bearing one. MATLAB Production Server answers 404 for an
    % archive it has accepted but not yet finished unpacking, which is why
    % internal.initialize defaults to retry=30 and exist/list default to 10 --
    % those budgets are a deployment wait, not error handling. Dropping 404
    % here would silently shorten it.
    %
    % Every other client error is a property of the request itself -- a
    % missing session id, an unsupported protocol version, a bad method -- and
    % resending it unchanged only multiplies the failure and the delay before
    % the caller sees it.
    retryable = [404 408 429];  % Not Found (still loading), Timeout, Too Many

    tries = 0;
    retry = true;

    while retry && tries <= opts.retry

        % Send the request and retrieve returned status code.
        httpOptions = matlab.net.http.HTTPOptions(...
            ConnectTimeout=opts.timeout, ResponseTimeout=opts.timeout);
        response = request.send(uri,httpOptions);
        tries = tries + 1;

        retry = ismember(double(response.StatusCode), retryable);

        % Pause only when another attempt is actually coming.
        if retry && tries <= opts.retry && opts.delay > 0
            pause(opts.delay);
        end
    end

    % If failure, throw as caller to make it easier to pinpoint where error
    % occurred.
    try
        prodserver.mcp.internal.requireSuccess(response,uri, ...
            request=opts.label);
    catch me
        throwAsCaller(me);
    end
