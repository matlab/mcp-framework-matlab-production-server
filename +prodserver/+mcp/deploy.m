function endpoint = deploy(archive,host,port,opts)
%deploy Upload an MCP-enabled CTF archive to a MATLAB Production Server
%instance.
%   endpoint = deploy(archive,host,opts) deploys ARCHIVE to the MATLAB 
%       Production Server running on HOST using optional inputs OPTS.
%       Returns the MCP URL in ENDPOINT.

%   endpoint = deploy(archive,host,port,opts) deploys ARCHIVE to the MATLAB
%       Production Server running at HOST:PORT using optional inputs OPTS.
%       Returns the MCP URL in ENDPOINT.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        % Archive to upload to <scheme>://<host>:<port>. Must exist.
        archive string { mustBeFile }
        % Network address of machine host MATLAB Production Server
        host string { prodserver.mcp.validation.mustBeHost } = "localhost";
        % Port number on host
        port double {prodserver.mcp.validation.mustBePortNumber} = 9910;
        % HTTP or HTTPS
        opts.scheme string {prodserver.mcp.validation.mustBeScheme} = "http";
        % Should upload overwrite existing archive with the same name?
        opts.overwrite logical = true;
        % Seconds to wait for the health check and ping requests to
        % complete. For the upload itself this is a CONNECT timeout only: a
        % large archive may legitimately take longer than this to transfer.
        opts.timeout double {prodserver.mcp.validation.mustBePositiveInteger} = 180;
        % How many times to retry HTTP requests.
        opts.retry double = 10
        % How many times to retry installation verification.
        opts.verify double = 5
        % How long to wait between retries
        opts.delay double = 2
    end

    % Allow server to be a complete URL, beginning with <scheme>://. In this
    % case, ignore port.
    url = host;
    if prodserver.mcp.validation.isuri(url) == false
        url = sprintf("%s://%s:%d",opts.scheme,host,port);
    else
        prodserver.mcp.validation.mustBeServer(url);

        % Make sure URL does not end with /
        url = strtrim(url);
        endSlash = "/"+textBoundary("end");
        if endsWith(url,endSlash)
            url = erase(url,endSlash);
        end

        % Also, don't allow port or scheme to have values other than the
        % default.
        if strcmp(opts.scheme,"http") == false
            error("prodserver:mcp:AmbiguousScheme", "Cannot specify both " + ...
                "URL and SCHEME.");
        end
        if port ~= 9910
            error("prodserver:mcp:AmbiguousPort", "Cannot specify both " + ...
                "URL and PORT.");
        end
    end

    % url must be the address of an active MATLAB Production Server
    % instance. isserver allows the server some grace period in case it is
    % still starting up. This is the only health check: uploadCTF relies on
    % it rather than making its own.
    [~, isActive] = prodserver.mcp.validation.isserver(url, ...
        retry=opts.retry, timeout=opts.timeout, delay=opts.delay);
    if ~isActive
        error("prodserver:mcp:ServerUnresponsive", ...
            "The server at %s did not respond to a health check. " + ...
            "Check to be sure the server is running and that you have " + ...
            "permissions to access it.",url);
    end

    % Upload!
    [status, detail] = prodserver.mcp.internal.uploadCTF(archive,url,...
        overwrite=opts.overwrite,retry=opts.retry,timeout=opts.timeout, ...
        delay=opts.delay);

    % Check the upload before waiting on the archive. Uploading and
    % initializing are separate phases: this status describes only the
    % synchronous transfer, while unpacking and loading happen afterwards and
    % show up as 404s that the verification loop below is right to wait out.
    % So a non-OK status here will never improve on its own -- nothing re-sends
    % the archive, and an archive the server never accepted will never appear.
    %
    % The status used to be discarded. The verification loop then spent its
    % whole budget pinging for an archive that was never installed and blamed
    % DeployedArchiveUnresponsive, telling the user to raise timeouts and retry
    % counts -- pointing away from the upload the server had already refused.
    [uploadFailed, permanent] = classifyUpload(status);
    if uploadFailed
        if isempty(status)
            % No response at all: every attempt timed out, or there was no
            % budget to attempt with. Nothing is known about the server's
            % opinion, so do not invent one.
            error("prodserver:mcp:ArchiveUploadNoResponse", ...
                "Uploading %s to %s produced no response after %d " + ...
                "attempt(s) with a %d second timeout. %s", ...
                archive, url, opts.retry, opts.timeout, detail);
        elseif permanent
            % 4xx: a property of the request or of the server's configuration.
            % Retrying verbatim cannot help.
            error("prodserver:mcp:ArchiveUploadRejected", ...
                "The server at %s rejected the upload of %s with HTTP %d. " + ...
                "%s", url, archive, double(status), detail);
        else
            % 5xx: the server failed to install an archive it was willing to
            % talk about. Observed to succeed unchanged on a later attempt, so
            % say that rather than implying the archive is at fault.
            error("prodserver:mcp:ArchiveUploadFailed", ...
                "The server at %s failed to install %s: HTTP %d. %s " + ...
                "This is a server-side failure and may be transient -- " + ...
                "check the server log, then try again.", ...
                url, archive, double(status), detail);
        end
    end

    % Assigned before the verify block, which used to be the only place it
    % was set, so verify=0 could not return the endpoint.
    [~,archiveName] = fileparts(archive);
    prefix = sprintf('%s/%s', url, archiveName);

    if opts.verify
        % Verify that upload was successful: ping the archive until the
        % archive answering is the one uploaded. Allow a few 404 responses
        % to give the server time to unpack a new archive. An update is
        % slower to show: the server answers with the archive it replaces
        % for several seconds after the upload returns, and that one says
        % pong too. Only the build's UUID tells them apart.
        expected = prodserver.mcp.internal.archiveUUID(archive);
        verifyArchive(sprintf("%s/ping",prefix), url, archiveName, ...
            expected, opts);
    end

    % Success! Network address of MCP endpoint. 
    endpoint = sprintf("%s%s", prefix, prodserver.mcp.MCPConstants.MCP);
end


function verifyArchive(pingURL, url, archiveName, expected, opts)
%verifyArchive Wait until the archive answering ping is the build EXPECTED.
%   The archive names its build in a header (see pingHandler). One built
%   before it did is asked about through discovery, and when that is turned
%   off, any pong is taken as the answer, as it always was. So is any pong
%   when EXPECTED is empty: the uploaded file's UUID couldn't be read.
%
%   Two answers in a row from that build: each ping may reach a different
%   worker, and they need not all change over at once.

    import prodserver.mcp.MCPConstants

    request = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET);
    uri = matlab.net.URI(pingURL);
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout, ...
        ResponseTimeout=opts.timeout);

    needed = 2;
    matched = 0;
    live = "";
    status = [];
    attempts = opts.verify*opts.retry;
    for attempt = 1:attempts
        response = request.send(uri, httpOpts);
        status = double(response.StatusCode);
        text = bodyText(response);
        % Production Server says why it failed in the status line's reason
        % phrase -- all that webread's error message, which this loop used
        % to read, contains -- so look there as well as in the body.
        why = reasonPhrase(response) + " " + text;
        if status == 200 && strcmpi(strtrim(text), MCPConstants.Pong)
            live = answeringBuild(response, url, archiveName, opts);
            if strlength(expected) == 0 || strlength(live) == 0
                return
            end
            if live == expected
                matched = matched + 1;
                if matched >= needed
                    return
                end
                continue
            end
            % The archive the upload replaces.
            matched = 0;
        elseif status == 404 || (status == 500 && contains(why, "End of file"))
            % Server is likely still unpacking new archive
        elseif status == 500 && contains(why, "pipe") && contains(why, "ended")
            error("prodserver:mcp:NeedMultiMCOSMode", ...
                "Internal error loading archive. Restart server in " + ...
                "multi-MCOS mode: set environment variable " + ...
                prodserver.mcp.internal.Constants.MultiMCOSEnvVar + ...
                " to ""true"" on server machine and restart server.");
        else
            break
        end
        % A brief pause, to let the server get its house in order -- if
        % another attempt is coming.
        if attempt < attempts
            pause(opts.delay);
        end
    end

    if strlength(live) > 0
        error("prodserver:mcp:DeployedArchiveStale", ...
            "Archive %s on server at %s is still the build it replaces " + ...
            "(%s), not the one uploaded (%s). Check server logs for " + ...
            "errors or increase retry count (%d) or retry delay (%d " + ...
            "seconds) and try again.", archiveName, url, live, expected, ...
            opts.retry, opts.delay);
    end
    answer = "";
    if ~isempty(status)
        answer = sprintf(" Its last answer was HTTP %d.", status);
    end
    error("prodserver:mcp:DeployedArchiveUnresponsive", ...
        "Archive %s on server at %s did not respond to ping request.%s " + ...
        "Check server logs for errors or increase timeout (%d seconds), " + ...
        "retry count (%d) or retry delay (%d seconds) and try again.", ...
        archiveName, url, answer, opts.timeout, opts.retry, opts.delay);
end


function live = answeringBuild(response, url, archiveName, opts)
%answeringBuild The UUID of the build that answered a ping: the header, or
%   discovery's archiveUuid for an archive that doesn't send it. Empty if
%   neither says, and then the caller takes the pong as the answer.
%
%   Discovery is server metadata, so it answers at once or not usefully at
%   all: it is given at most Constants.DiscoveryTimeout seconds. With the
%   whole timeout (180 seconds by default), a discovery that hung cost that
%   much, and one that answered slowly cost it on every ping until the old
%   build stopped answering.
    live = "";
    field = response.getFields(prodserver.mcp.internal.Constants.ArchiveUUIDHeader);
    if ~isempty(field)
        live = string(field(1).Value);
        return
    end
    try
        found = webread(url + "/api/discovery", weboptions(ContentType="text", ...
            Timeout=min(opts.timeout, ...
            prodserver.mcp.internal.Constants.DiscoveryTimeout)));
        archives = jsondecode(found).archives;
        name = matlab.lang.makeValidName(archiveName);
        if isfield(archives, name) && isfield(archives.(name), "archiveUuid")
            live = string(archives.(name).archiveUuid);
        end
    catch
        % Discovery turned off, too slow, or not an answer: nothing more to
        % go on.
    end
end


function why = reasonPhrase(response)
%reasonPhrase The reason phrase of a response's status line; empty if none.
    why = "";
    if ~isempty(response.StatusLine)
        why = string(response.StatusLine.ReasonPhrase);
    end
end


function text = bodyText(response)
%bodyText A response's body as text; empty if it has none.
    text = "";
    if ~isempty(response.Body) && (ischar(response.Body.Data) || ...
            isstring(response.Body.Data))
        text = string(response.Body.Data);
    end
end


function [failed, permanent] = classifyUpload(status)
%classifyUpload Did the upload fail, and is retrying it pointless?
%   Only OK means the archive was accepted -- measured against R2026b, a
%   successful upload answers 200 rather than 201, so there is no success
%   status to admit beyond this one.
%
%   PERMANENT separates a refusal from a failure. A 4xx is a property of the
%   request or of the server's configuration: the wrong archive name, archive
%   management disabled, an overwrite the caller forbade. Those cannot change
%   while the request does not. A 5xx is the server failing at something it
%   agreed to attempt, which has been observed to succeed on a later identical
%   attempt, so it is reported as possibly transient. An empty status means no
%   response was obtained and is classified as not permanent, since nothing is
%   known either way.

    failed = isempty(status) || status ~= matlab.net.http.StatusCode.OK;
    permanent = ~isempty(status) && ...
        double(status) >= 400 && double(status) < 500;
end
