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

    import prodserver.mcp.internal.Constants

    tries = 0;

    % Retry only the statuses that can change without the request changing:
    % 404 (Production Server answers 404 while an archive is still being
    % unpacked, with an empty body), 408 and 429. Any other 4xx is a verdict
    % on the request itself, and re-sending it only multiplies the failure
    % and the delay (XD14).
    retryable = true;
    while tries <= opts.retry && retryable

        % Send the request and retrieve returned status code.
        httpOptions = matlab.net.http.HTTPOptions(...
            ConnectTimeout=opts.timeout, ResponseTimeout=opts.timeout);
        response = request.send(uri,httpOptions);
        sc = response.StatusCode;

        % A 4xx carrying a JSON-RPC error body is a deterministic rejection
        % -- an unsupported protocol version, a header mismatch, a malformed
        % request. The server will answer identically every time, so retrying
        % only multiplies the failure and the delay. Stop immediately and let
        % requireSuccess report it. The same predicate requireSuccess uses,
        % so the two can never disagree about what counts as an error body.
        if ~isempty(response.Body) && ...
                prodserver.mcp.internal.isJsonRpcError(response.Body.Data)
            break
        end

        retryable = ismember(double(sc), Constants.RetryableStatus);
        tries = tries + 1;

        % Pause only when another attempt is actually coming (ND11).
        if retryable && tries <= opts.retry && opts.delay > 0
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
