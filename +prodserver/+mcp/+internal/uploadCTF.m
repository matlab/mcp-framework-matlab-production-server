function status = uploadCTF(ctf, url, opts)
%uploadCTF Upload a CTF to the active server at url.
%
%   status = uploadCTF(CTF, URL) uploads the archive CTF to the
%   active (running) MATLAB Production Server at network address URL.
%
% Upload will fail if the server is not running or if the server does not
% allow remote archive management. To allow remote archive management, 
% set --enable-archive-management in the instance configuration file.
%
% This is an internal function and thus only minimally validates inputs.

% Copyright 2025, The MathWorks, Inc.

    arguments
        ctf string { mustBeFile }
        url string { prodserver.mcp.validation.mustBeURI }
        opts.overwrite logical = true
        opts.scheme string = "http";
        opts.retry double = 2
        opts.timeout double = 30
    end
 
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
 
    % Upload -- only retry on timeout. No error retry.
    status = matlab.net.http.StatusCode.BadRequest;
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout);
    n = 1;
    while n <= opts.retry && status ~= matlab.net.http.StatusCode.OK
        try
            upload_response = request.send(mpsURI,httpOpts);
            status = upload_response.StatusCode;
        catch ex
            % Look for timeout exceptions and retry. Heuristic.
            rpt = getReport(ex);
            if contains(rpt,"timeout",IgnoreCase=true) == false && ...
                    contains(rpt,"timed out",IgnoreCase=true) == false
                rethrow(ex);
            end
        end
        n = n + 1;
    end
end
