function response = sendRequest(request,uri,opts)
% sendRequest Send an HTTP request to a URL. Optional arguments to control
% timeout and retry behavior.

% Copyright 2025, The MathWorks, Inc.
    arguments
        request (1,1) matlab.net.http.RequestMessage
        uri (1,1) matlab.net.URI
        opts.label string = ""
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 3
        opts.delay double {mustBePositive} = 2
    end

    import prodserver.mcp.internal.Constants

    tries = 0; sc = Constants.HTTPClientError;

    % While retries not exhausted and HTTP protocol error occurred, try
    % again.
    while tries <= opts.retry && ...
            sc >= Constants.HTTPClientError && ...
            sc < Constants.HTTPServerError

        % Send the request and retrieve returned status code. 
        httpOptions = matlab.net.http.HTTPOptions(...
            ConnectTimeout=opts.timeout, ResponseTimeout=opts.timeout);
        response = request.send(uri,httpOptions);
        sc = response.StatusCode;

        % Pause for a 400-series error, if delay is > 0.
        if sc >= Constants.HTTPClientError && ...
            sc < Constants.HTTPServerError && opts.delay > 0
            pause(opts.delay);
        end
        
        tries = tries + 1;
    end

    % If failure, throw as caller to make it easier to pinpoint where error
    % occurred.
    try
        prodserver.mcp.internal.requireSuccess(response,uri, ...
            request=opts.label); 
    catch me
        throwAsCaller(me);
    end
