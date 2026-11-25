function response = sendRequest(request,uri,opts)
% sendRequest Send an HTTP request to a URL. Optional arguments to control
% timeout and retry behavior.
%
%   A retryable status (Constants.RetryableStatus) is retried up to retry
%   times, for any request. A request that failed without a response -- a
%   timeout or a refused connection -- is resent only if repeatable is
%   true, and then only resend times: it may have reached the server, and
%   only a request that changes nothing, such as tools/list, is safe to send
%   twice. A tools/call isn't. A timeout that isn't resent, or still fails,
%   is prodserver:mcp:RequestTimeout.
%
%   The two budgets are separate because their costs differ: a status comes
%   back at once, but a request with no answer waits the whole timeout. So
%   a caller's retry, set for quick statuses (30, for a 404 while an
%   archive unpacks), can't turn a server that never answers into a wait of
%   30 timeouts.
%
%   A 404 with an empty body is Production Server's own: no archive answers
%   at URI. It gives the same answer for an archive it is still deploying,
%   so it is retried like any retryable status, and if it is still the
%   answer when the retries run out, the error is
%   prodserver:mcp:UnknownArchive. A 404 the framework sends carries a body,
%   and stays an HttpError or RemoteError.

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
        request (1,1) matlab.net.http.RequestMessage
        uri (1,1) matlab.net.URI
        opts.label string = ""
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = ...
            prodserver.mcp.internal.Constants.ArchiveRetry
        opts.delay double {mustBePositive} = ...
            prodserver.mcp.internal.Constants.ArchiveDelay
        opts.repeatable (1,1) logical = false
        % Resends after no answer, for a repeatable request. One covers a
        % worker loading an archive after a restart: two timeouts in all.
        opts.resend double {mustBeNonnegative, mustBeInteger} = 1
    end

    import prodserver.mcp.internal.Constants

    tries = 0;
    unanswered = 0;
    started = tic;

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
        try
            response = request.send(uri,httpOptions);
        catch me
            % No response. A server that has just started can take longer
            % than one timeout to answer its first request to an archive,
            % while a worker loads it. Counted apart from tries: see above.
            unanswered = unanswered + 1;
            if opts.repeatable && unanswered <= opts.resend && ...
                    prodserver.mcp.internal.isTransientError(me, status=[])
                pause(opts.delay);
                continue
            end
            if prodserver.mcp.internal.isTransientError(me, ...
                    connection=false, status=[])
                throwAsCaller(requestTimeout(me, uri, opts, unanswered));
            end
            % MATLAB's own error, which quotes the address as given,
            % password included.
            throwAsCaller(prodserver.mcp.internal.redactedError(me));
        end
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

        % A 404 only if it is Production Server's: one with a body came from
        % the archive, which is there, and will say the same again.
        retryable = ismember(double(sc), Constants.RetryableStatus) && ...
            (double(sc) ~= 404 || isArchiveMissing(response));
        tries = tries + 1;

        % Say, once, why the wait is coming: the user who mistyped the
        % archive's name can stop it at once, and the one who just deployed
        % it can wait without wondering.
        if tries == 1 && tries <= opts.retry && isArchiveMissing(response)
            waitingForArchive(uri, opts.retry * opts.delay);
        end

        % Pause only when another attempt is actually coming (ND11).
        if retryable && tries <= opts.retry && opts.delay > 0
            pause(opts.delay);
        end
    end

    % Not an HttpError: isProtocolError would answer it by forgetting the
    % endpoint's protocol revision and asking again, and no revision changes
    % this answer, which comes before any archive code runs.
    if isArchiveMissing(response)
        throwAsCaller(unknownArchive(uri, toc(started)));
    end

    % If failure, throw as caller to make it easier to pinpoint where error
    % occurred.
    try
        prodserver.mcp.internal.requireSuccess(response,uri, ...
            request=opts.label);
    catch me
        throwAsCaller(me);
    end
end

function tf = isArchiveMissing(response)
% Production Server's own 404: no body. The framework's 404s have one.
    tf = double(response.StatusCode) == 404 && ...
        (isempty(response.Body) || isempty(response.Body.Data));
end

function err = unknownArchive(uri, waited)
% The framework's error for an archive that never answered. Not naming the
% request: whichever came first, often the internal server/discover probe,
% the answer is about the archive.
    err = MException("prodserver:mcp:UnknownArchive", ...
        "No archive answered at %s: MATLAB Production Server " + ...
        "answered 404 (not found) for %d seconds. It answers the same " + ...
        "way for an archive that doesn't exist and for one it is still " + ...
        "deploying or starting, so the two can't be told apart. If this " + ...
        "is the first request to the archive since it was deployed or " + ...
        "the server started, try again: a slow start can take several " + ...
        "minutes. Otherwise, check the archive name in the endpoint.%s", ...
        prodserver.mcp.io.redactURI(string(uri)), round(waited), archiveHint(uri));
end

function waitingForArchive(uri, seconds)
% The warning, prodserver:mcp:WaitingForArchive, that a wait for an archive
% has begun. Without a backtrace: it says what is happening, not where.
    backtrace = warning("query", "backtrace");
    warning("off", "backtrace");
    restore = onCleanup(@() warning(backtrace)); %#ok<NASGU>
    warning("prodserver:mcp:WaitingForArchive", ...
        "No archive answers at %s yet. MATLAB Production Server answers " + ...
        "the same way for an archive it is still deploying, so trying " + ...
        "again for up to %d seconds. Press Ctrl+C to stop.%s", ...
        prodserver.mcp.io.redactURI(string(uri)), round(seconds), archiveHint(uri));
end

function hint = archiveHint(uri)
% What the server's /api/discovery says of the archive URI names, as a
% sentence to add to a message, starting with a space; "" if nothing. If it
% lists the archive, the archive is loading; if it lists similar names, the
% endpoint may be mistyped. Discovery may be turned off, or slow: then
% there is no hint, and nothing fails.
    hint = "";
    % The archive's own routes: /mcp, and /ping, which metrics checks first.
    archive = string(regexp(char(string(uri)), ...
        "/([^/?#]+)/(mcp|ping|signature)$", "tokens", "once"));
    if isempty(archive)
        archive = "";
    end
    archive = archive(1);
    server = string(regexp(char(string(uri)), ...
        "^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]+", "match", "once"));
    if strlength(archive) == 0 || strlength(server) == 0
        return
    end
    try
        found = webread(server + "/api/discovery", weboptions( ...
            ContentType="text", ...
            Timeout=prodserver.mcp.internal.Constants.DiscoveryTimeout));
        listed = jsondecode(found).archives;
    catch
        return
    end
    names = archiveNames(listed);
    if any(names == archive)
        hint = sprintf(" The server lists an archive named '%s', so " + ...
            "it is probably still starting.", archive);
        return
    end
    near = nearNames(archive, names);
    if ~isempty(near)
        if isscalar(near)
            kind = "an archive with a similar name";
        else
            kind = "archives with similar names";
        end
        hint = sprintf(" The server has %s: %s.", kind, ...
            strjoin("'" + near + "'", ", "));
    end
end

function names = archiveNames(listed)
% The names the archives were deployed under. Each is a field of LISTED,
% but jsondecode renames one that isn't a MATLAB identifier. Its UUID
% begins with the name it was built under, which is the deployed name
% unless the archive file was renamed: so the UUID's name is used only to
% undo jsondecode's renaming, when it renames to exactly this field.
    names = string(fieldnames(listed))';
    for k = 1:numel(names)
        entry = listed.(names(k));
        if isstruct(entry) && isfield(entry, "archiveUuid")
            built = regexprep(string(entry.archiveUuid), ...
                "_[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", "");
            if built ~= names(k) && ...
                    matlab.lang.makeValidName(built) == names(k)
                names(k) = built;
            end
        end
    end
    names = unique(names, "stable");
end

function near = nearNames(name, names)
% Up to three of NAMES within a few edits of NAME, ignoring case, closest
% first: about one edit in four characters, and at least one.
    limit = max(1, floor(strlength(name) / 4));
    d = arrayfun(@(n) levenshtein(lower(name), lower(n)), names);
    [d, order] = sort(d);
    near = names(order(d <= limit));
    near = near(1:min(3, end));
end

function d = levenshtein(a, b)
% Levenshtein distance between strings A and B.
    a = char(a);
    b = char(b);
    row = 0:numel(b);
    for i = 1:numel(a)
        previous = row;
        row(1) = i;
        for j = 1:numel(b)
            row(j+1) = min([previous(j+1) + 1, row(j) + 1, ...
                previous(j) + (a(i) ~= b(j))]);
        end
    end
    d = row(end);
end

function err = requestTimeout(me, uri, opts, tries)
% The framework's error for a request that got no answer in time. ME, the
% transport's own error, redacted, is its cause.
    what = "The request";
    if strlength(opts.label) > 0
        what = "The " + opts.label + " request";
    end
    again = "Try again shortly.";
    if ~opts.repeatable
        % Not resent: it may have reached the server and been acted on.
        again = "The server may still have acted on it: check before " + ...
            "sending it again.";
    end
    err = MException("prodserver:mcp:RequestTimeout", ...
        "%s to %s got no answer within %g seconds (%d attempt(s)). A " + ...
        "server that has just started or restarted can take longer to " + ...
        "answer its first request to an archive, while a worker loads " + ...
        "it, even after /api/health says ok. %s", ...
        what, prodserver.mcp.io.redactURI(string(uri)), opts.timeout, tries, again);
    err = err.addCause(prodserver.mcp.internal.redactedError(me));
end
