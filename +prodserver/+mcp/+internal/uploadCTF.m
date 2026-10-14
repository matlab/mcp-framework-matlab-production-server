function [status, detail] = uploadCTF(ctf, url, opts)
%uploadCTF Upload a CTF to the active server at url.
%
%   status = uploadCTF(CTF, URL) uploads the archive CTF to the
%   active (running) MATLAB Production Server at network address URL.
%
%   [status, detail] = uploadCTF(CTF, URL) also returns what the server said
%   about the outcome.
%
%   STATUS is a matlab.net.http.StatusCode, or EMPTY when no response was
%   ever obtained -- every attempt timed out, or the retry budget was zero.
%   Empty is deliberately distinguishable from a status: this function used
%   to seed STATUS with BadRequest, so a request that never completed was
%   indistinguishable from one the server answered with 400.
%
%   Only matlab.net.http.StatusCode.OK means the archive was accepted;
%   measured against R2026b, a successful upload answers 200, not 201.
%
%   DETAIL is the server's explanation as text, empty when there is none. The
%   status alone is a thin diagnosis: MATLAB Production Server reports an
%   upload it refused as a bare 500, and names the actual reason -- "Archive
%   Create Error" and the like -- only in the response body. Callers need that
%   text to tell the user anything useful, so it is no longer discarded.
%
% Upload will fail if the server is not running or if the server does not
% allow remote archive management. To allow remote archive management,
% set --enable-archive-management in the instance configuration file.
%
% This is an internal function and thus only minimally validates inputs.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        ctf string { mustBeFile }
        url string { prodserver.mcp.validation.mustBeURI }
        opts.overwrite logical = true
        opts.scheme string = "http";
        opts.retry double = 2
        opts.timeout double = 30
        % Seconds to wait between upload attempts. A rejected upload is not
        % always a permanent one, and the server needs wall-clock time rather
        % than another immediate request -- see the send loop below.
        opts.delay double = 2
    end

    import prodserver.mcp.internal.hasField
 
    [~,ctfName,ext] = fileparts(ctf);

    % ext must be CTF
    if strcmpi(ext,".ctf") == false
        error("prodserver:mcp:ArchiveMustBeCTF", ...
            "File to upload does not have .CTF extension. " + ...
            "MATLAB Production Server supports CTF archives only. " + ...
            "File: %s", ctf)
    end

    [~,isActive] = prodserver.mcp.validation.isserver(url,...
        retry=opts.retry,timeout=opts.timeout);
    if isActive == false
        error("prodserver:mcp:InactiveServer", ...
   "No response from server '%s'. Check server status and access " + ...
            "permissions",url);
    end
 
    % Remote archive management endpoint
    archiveURL = sprintf("%s/api/archives?ctf=%s",url,ctfName);

    % List / Show
    webOpts = weboptions(Timeout=opts.timeout);
    n = 1;
    while n <= opts.retry
        try
            list_response = webread(archiveURL,webOpts);
            % If we got a good response, exit the loop.
            if all(hasField(list_response,["action","result","archive"]))
                n = opts.retry + 1;
            end
        catch ex
            % No recovery from this failure, no sense in retrying.
            if contains(ex.message,"Archive Management Disabled")
                error("prodserver:mcp:ArchiveManagementDisabled", ...
    "Cannot upload to %s because that server has archive management " + ...
    "disabled. Enable archive management and try again.", url);
            end
            % We've tried as many times as we're allowed.
            if n == opts.retry
                rethrow(ex);
            end
        end
        n = n + 1;
    end
 
    % Read the bytes of the CTF archive. All of them. This may result in a
    % gigantic request body.
    fp = fopen(ctf);
    closeFP = onCleanup(@()fclose(fp));
    data = fread(fp,'*uint8');
 
    % Content type is binary.
    contentTypeField = matlab.net.http.field.ContentTypeField( ...
        'application/octet-stream');
 
    % Request method is POST, since we're changing server state.
    requestMethod = matlab.net.http.RequestMethod.POST;

    % Is an archive of the same name already present on the server?
    alreadyThere = ismember(ctfName, list_response.archive);
    alreadyThere = list_response(alreadyThere).result == true;

    % Overwrite or error for pre-existing archives.
    if alreadyThere && opts.overwrite == false
        error("prodserver:mcp:ArchiveOverwriteDisabled", ...
            "Archive %s already installed on %s. Set overwrite to " + ...
            "true to replace the existing archive.", ctfName, url);
    end

    % If the archive is already present, we must use PUT to overwrite it.
    if (alreadyThere) % update if already exists
        requestMethod = matlab.net.http.RequestMethod.PUT;
    end
 
    % Create the request message with appropriate method and binary data
    request = matlab.net.http.RequestMessage(requestMethod, ...
        contentTypeField, data);
 
    % Create URI with query params:
    mpsURI = matlab.net.URI(archiveURL);
 
    % Upload. Retry on a timeout, and on a 5xx: a server-side failure here is
    % not reliably permanent -- an upload refused with 500 has been observed to
    % succeed unchanged on a later attempt, and the hot folder takes 5-15
    % seconds to settle -- so the server is given wall-clock time rather than
    % another immediate request. The previous loop re-sent on any non-OK status,
    % despite a comment claiming it only retried timeouts, and re-sent
    % immediately, so it could not outlast whatever it was retrying for.
    %
    % A 4xx is not retried at all. It is a property of the request or of the
    % server's configuration -- the wrong name, archive management disabled, an
    % overwrite the caller forbade -- so re-sending the same bytes cannot change
    % the answer, and re-sending a whole CTF to be told no again just delays the
    % diagnosis by RETRY*DELAY seconds.
    %
    % Empty, not BadRequest, is the starting value: it has to stay possible to
    % tell "the server said 400" from "nothing was ever sent".
    status = matlab.net.http.StatusCode.empty;
    detail = "";
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout);
    n = 1;
    while n <= opts.retry && worthAnotherTry(status)
        try
            upload_response = request.send(mpsURI,httpOpts);
            status = upload_response.StatusCode;
            detail = responseDetail(upload_response);
        catch ex
            % Look for timeout exceptions and retry. Heuristic.
            rpt = getReport(ex);
            if contains(rpt,"timeout",IgnoreCase=true) == false && ...
                    contains(rpt,"timed out",IgnoreCase=true) == false
                rethrow(ex);
            end
            detail = string(ex.message);
        end

        % Pause only when another attempt is actually coming.
        if n < opts.retry && worthAnotherTry(status) && opts.delay > 0
            pause(opts.delay);
        end
        n = n + 1;
    end
end


function tf = worthAnotherTry(status)
%worthAnotherTry Could re-sending this upload plausibly produce a better answer?
%   Empty means nothing was received yet, or every attempt so far timed out:
%   worth another try. A 5xx is the server failing at something it agreed to
%   attempt, which may not still be true a few seconds later. Anything else --
%   OK, or a 4xx refusal -- is the server's settled answer.

    tf = isempty(status) || double(status) >= 500;
end


function detail = responseDetail(response)
%responseDetail The server's explanation of an upload outcome, as text.
%   MATLAB Production Server answers the archive-management endpoint with
%   JSON, but a failure can also arrive as plain text or as nothing at all, so
%   every shape has to degrade to something printable rather than throw while
%   building an error message.

    detail = "";

    body = response.Body;
    if ~isempty(body)
        data = body.Data;
        if isstruct(data)
            % The documented shape: {"action":...,"result":...,"message":...}.
            % Prefer a message, fall back to the whole decoded struct.
            for field = ["message" "error" "result"]
                if isfield(data,field) && ~isempty(data.(field)) && ...
                        (ischar(data.(field)) || isstring(data.(field)))
                    detail = string(data.(field));
                    break
                end
            end
            if strlength(detail) == 0
                detail = strtrim(string(formattedDisplayText(data)));
            end
        elseif ischar(data) || isstring(data)
            detail = strtrim(string(data));
        end
    end

    % No body, or nothing usable in it: the reason phrase is better than
    % silence.
    if strlength(detail) == 0 && ~isempty(response.StatusLine)
        detail = string(response.StatusLine.ReasonPhrase);
    end
end
