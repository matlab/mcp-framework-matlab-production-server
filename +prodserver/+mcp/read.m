function result = read(endpoint, uri, opts)
% read Read Model Context Protocol resource from server at endpoint.
%
%    result = read(ENDPOINT, URI) reads the resource identified by URI
%    from the MCP server at ENDPOINT. URI is the unique resource
%    identifier returned by list(ENDPOINT, "Resource").

% Copyright 2025-2026 The MathWorks, Inc.

    arguments (Input)
        endpoint (1,1) string {prodserver.mcp.validation.mustBeMCPServer}
        uri string {mustBeNonempty}
        opts.TextAsString logical = true;
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 3
        opts.delay double {mustBePositive} = 2
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField

    % Require that the server publish resources.
    [session,id] = prodserver.mcp.internal.initialize(endpoint, ...
        require="Resource");
    terminator = onCleanup(@()prodserver.mcp.internal.terminate( ...
        endpoint,session)); %#ok<NASGU>

    %
    % List resources, to verify that URI exists at ENDPOINT
    %

    [items,id] = prodserver.mcp.internal.list(endpoint,session, ...
        "Resource",id=id);
    resources = items.resources;

    % Out, out, damn char!
    uris = cellfun(@(t)string(t.uri),resources);

    headers = [
        matlab.net.http.HeaderField('Content-Type', 'application/json'), ...
        matlab.net.http.HeaderField(MCPConstants.ProtocolVersion, ...
        MCPConstants.protocolVersion), ...
        matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
        ];

    result = cell(size(uri));
    istext = false(1,numel(uri));
    for n = 1:numel(uri)

        found = strcmp(uri(n),uris);
        if nnz(found) ~= 1
            error("prodserver:mcp:NonUniqueResource", "Resources must " + ...
                 "exist and have unique URIs. Found %d resources " + ...
                 "with URI %s.", nnz(found), ...
                uri(n));
        end
        % found is known to have only one non-zero element, so this is safe
        % for any cell-array of structures.
        r = resources{found};

        % Fetch the resource contents

        data.jsonrpc = MCPConstants.jrpcVersion;
        data.id = id;
        data.method = "resources/read";
        data.params.uri = r.uri;

        body = matlab.net.http.MessageBody(data);
        request = matlab.net.http.RequestMessage('POST', headers, body);

        response = prodserver.mcp.internal.sendRequest(request,endpoint, ...
            timeout=opts.timeout, retry=opts.retry, delay=opts.delay, ...
            label=data.method);

        % Expect a contents field
        if hasField(response,"Body.Data.result.contents") == false
            error("prodserver:mcp:ResourceMissingContents", ...
                "Resource %s returned successfully but " + ...
                "without contents.", r.uri);
        end
        contents = response.Body.Data.result.contents;
        if prodserver.mcp.jsonrpc.isMIMETypeText(contents.mimeType)
            result{n} = contents.text;
            istext(n) = true;
        else
            result{n} = contents.blob;
        end
        % If all the results are text, return a string array, since they
        % are much easier to use than cell arrays. Also, for the 80% case,
        % this returns a string scalar -- the input resource will be a
        % scalar 80% of the time if not more often.
        if all(istext) && opts.TextAsString == true
            result = string(result);
        end
    end
end
