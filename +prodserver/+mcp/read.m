function result = read(endpoint, resource, opts)
% read Read Model Context Protocol resource from server at endpoint.
%
%    result = read(ENDPOINT, RESOURCE) reads RESOURCE from the MCP server
%    at ENDPOINT.
    arguments (Input)
        endpoint (1,1) string
        resource string
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

    %
    % List resources, to verify that RESOURCE exists at ENDPOINT
    %

    [items,id] = prodserver.mcp.internal.list(endpoint,session, ...
        "Resource",id=id);
    resources = items.resources;

    % Out, out, damn char!
    names = cellfun(@(t)string(t.name),resources);

    headers = [
        matlab.net.http.HeaderField('Content-Type', 'application/json'), ...
        matlab.net.http.HeaderField(MCPConstants.ProtocolVersion, ...
        MCPConstants.protocolVersion), ...
        matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
        ];

    result = cell(size(resource));
    istext = false(1,numel(resource));
    for n = 1:numel(resource)

        found = strcmp(resource(n),names);
        if nnz(found) ~= 1
            error("prodserver:mcp:NonUniqueResource", "Resources must " + ...
                 "exist and have unique names. Found %d resources " + ...
                 "named %s.", nnz(found), ...
                resource(n));
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
