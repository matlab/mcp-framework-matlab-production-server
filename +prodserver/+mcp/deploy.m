function endpoint = deploy(archive,host,port,opts)
%deploy Upload an MCP-enabled CTF archive to a MATLAB Production Server
%instance.

% Copyright 2025, The MathWorks, Inc.

    arguments
        % Archive to upload to <scheme>://<host>:<port>. Must exist.
        archive string { mustBeFile }
        % Network address of machine host MATLAB Production Server
        host string {prodserver.mcp.validation.mustBeHostName} = "localhost";
        % Port number on host
        port double {prodserver.mcp.validation.mustBePortNumber} = 9910;
        % HTTP or HTTPS
        opts.scheme string {prodserver.mcp.validation.mustBeScheme} = "http";
        % Should upload overwrite existing archive with the same name?
        opts.overwrite logical = true;
        % Number of seconds to wait for HTTP requests to complete.
        opts.timeout double {prodserver.mcp.validation.mustBePositiveInteger} = 180;
        % How many times to retry HTTP requests.
        opts.retry double = 2
        % How many times to retry installation verification.
        opts.verify double = 5
    end

    webOpts = weboptions(Timeout=opts.timeout);

    % host:port must be the address of an active MATLAB Production Server
    % instance.
    healthURL = sprintf("%s://%s:%d/api/health", opts.scheme, host, port);
    status = webread(healthURL,webOpts);
    if ~isstruct(status) || isfield(status,"status") == false || ...
        strcmpi(status.status,"ok") == false
        error("prodserver:mcp:ServerUnresponsive", ...
            "The server at %s:%d did not respond to a health check. " + ...
            "Check to be sure the server is running and that you have " + ...
            "permissions to access it.",host,port);
    end

    % Upload!
    prodserver.mcp.internal.uploadCTF(archive,host,port,...
        overwrite=opts.overwrite,retry=opts.retry,timeout=opts.timeout);

    if opts.verify
        % Verify that upload was successful. Send "ping" to the archive. 
        % Allow a few 404 responses to give the server time to unpack the 
        % archive, if necessary.
        [~,archiveName] = fileparts(archive);
        prefix = sprintf('%s://%s:%d/%s', opts.scheme, host, port, ...
            archiveName);
        pingURL = sprintf("%s/ping",prefix);
    
        n = 1; pong = string.empty;
        while n <= opts.retry && isempty(pong)
            try
                pong = webread(pingURL,webOpts);
            catch ex
                % Retry on 404 only -- after a brief pause, to let the 
                % server get its house in order.
                if contains(ex.identifier,"HTTP404")
                    % Server is likely unpacking new archive
                    pause(2);
                else
                    rethrow(ex);
                end
            end
            n = n + 1;
        end
        if strcmpi(pong,prodserver.mcp.MCPConstants.Pong) == false
            error("prodserver:mvp:DeployedArchiveUnresponsive", ...
    "Archive %s on server at %s:%d did not respond to ping request." + ...
    "Check server logs for errors or increase timeout and try " + ...
    "again.", archiveName, host, port);
        end
    end

    % Success! Network address of MCP endpoint. 
    endpoint = sprintf("%s%s", prefix, prodserver.mcp.MCPConstants.MCP);
end
