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
        % Number of seconds to wait for HTTP requests to complete.
        opts.timeout double {prodserver.mcp.validation.mustBePositiveInteger} = 180;
        % How many times to retry HTTP requests.
        opts.retry double = 10
        % How many times to retry installation verification.
        opts.verify double = 5
        % How long to wait between retries
        opts.delay double = 2
    end

    webOpts = weboptions(Timeout=opts.timeout);

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
    % instance. Allow the server some grace period in case it is still
    % starting up.
    healthURL = sprintf("%s/api/health", url);
    n = 1;
    status = [];
    while n <= opts.retry && isempty(status)
        try
            status = webread(healthURL,webOpts);
        catch me
            % Often occurs because server still starting up.
            if contains(me.identifier,"ConnectionRefused") || ...
                    contains(me.message,"could not connect to server",IgnoreCase=true) || ...
                    contains(me.message,"connection refused",IgnoreCase=true)
                pause(opts.delay);
            else
                rethrow(me);
            end
        end
        n = n + 1;
    end

    if ~isstruct(status) || isfield(status,"status") == false || ...
        strcmpi(status.status,"ok") == false
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

    if opts.verify
        % Verify that upload was successful. Send "ping" to the archive. 
        % Allow a few 404 responses to give the server time to unpack the 
        % archive, if necessary.
        [~,archiveName] = fileparts(archive);
        prefix = sprintf('%s/%s', url, archiveName);
        pingURL = sprintf("%s/ping",prefix);
    
        n = 1; pong = string.empty;
        while n <= opts.verify && isempty(pong)
            k = 1;
            while k <= opts.retry && isempty(pong)
                try
                    pong = webread(pingURL,webOpts);
                catch ex
                    % Retry on 404 and 500 with "end of file" only -- after 
                    % a brief pause, to let the server get its house in order.
                    if contains(ex.identifier,"HTTP404") || ...
      (contains(ex.identifier,"HTTP500") && contains(ex.message,"End of file"))
                        % Server is likely still unpacking new archive
                        pause(opts.delay);
                    elseif contains(ex.identifier,"HTTP500") && ...
                            contains(ex.message,"pipe") && contains(ex.message,"ended")
                        error("prodserver:mcp:NeedMultiMCOSMode", ...
                            "Internal error loading archive. Restart server in " + ...
                            "multi-MCOS mode: set environment variable " + ...
                            prodserver.mcp.internal.Constants.MultiMCOSEnvVar + ...
                            " to ""true"" on server machine and restart server.");
                    else
                        rethrow(ex);
                    end
                end
                k = k + 1;
            end
            n = n + 1;
        end
        if isempty(pong) || strcmpi(pong,prodserver.mcp.MCPConstants.Pong) == false 
            error("prodserver:mcp:DeployedArchiveUnresponsive", ...
    "Archive %s on server at %s did not respond to ping request. " + ...
    "Check server logs for errors or increase timeout (%d seconds), " + ...
    "retry count (%d) or retry delay (%d seconds) and try again.", ...
                archiveName, url, opts.timeout, opts.retry, opts.delay);
        end
    end

    % Success! Network address of MCP endpoint.
    endpoint = sprintf("%s%s", prefix, prodserver.mcp.MCPConstants.MCP);
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
