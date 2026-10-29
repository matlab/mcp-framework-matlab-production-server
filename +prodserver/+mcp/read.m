function result = read(endpoint, uri, opts)
% read Read Model Context Protocol resource from server at endpoint.
%
%    result = read(ENDPOINT, URI) reads the resource identified by URI
%    from the MCP server at ENDPOINT. URI is the unique resource
%    identifier returned by list(ENDPOINT, "Resource").
%
%    Text resources come back as string (char if TextAsString is false).
%    Binary resources come back as a uint8 row vector of the bytes.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments (Input)
        endpoint (1,1) string {prodserver.mcp.validation.mustBeMCPServer}
        uri string {mustBeNonempty}
        opts.protocol string = "discover"
        opts.TextAsString logical = true;
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 3
        opts.delay double {mustBePositive} = 2
    end

    try
        result = doRead(endpoint, uri, opts);
    catch me
        if opts.protocol == "discover" && prodserver.mcp.protocol.isProtocolError(me)
            prodserver.mcp.client.Adapter.create(endpoint, action="clear");
            result = doRead(endpoint, uri, opts);
        else
            rethrow(me);
        end
    end
end

function result = doRead(endpoint, uri, opts)
    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField

    client = prodserver.mcp.client.Adapter.create(endpoint, ...
        protocol=opts.protocol);
    client.connect(require="Resource", timeout=opts.timeout, ...
        delay=opts.delay, retry=opts.retry);
    cleanup = onCleanup(@()client.disconnect()); %#ok<NASGU>

    items = client.list("Resource", timeout=opts.timeout, ...
        delay=opts.delay, retry=opts.retry);
    resources = items.resources;

    uris = cellfun(@(t)string(t.uri), resources);

    result = cell(size(uri));
    istext = false(1, numel(uri));
    for n = 1:numel(uri)

        found = strcmp(uri(n), uris);
        if nnz(found) ~= 1
            error("prodserver:mcp:NonUniqueResource", "Resources must " + ...
                 "exist and have unique URIs. Found %d resources " + ...
                 "with URI %s.", nnz(found), uri(n));
        end
        r = resources{found};

        data = struct();
        data.jsonrpc = MCPConstants.jrpcVersion;
        data.method = "resources/read";
        data.params.uri = r.uri;

        response = client.send(data, timeout=opts.timeout, ...
            retry=opts.retry, delay=opts.delay);

        if hasField(response, "Body.Data.result.contents") == false
            error("prodserver:mcp:ResourceMissingContents", ...
                "Resource %s returned successfully but " + ...
                "without contents.", r.uri);
        end
        contents = response.Body.Data.result.contents;
        if prodserver.mcp.jsonrpc.isMIMETypeText(contents.mimeType)
            result{n} = contents.text;
            istext(n) = true;
        else
            % blob is Base64 on the wire; return the bytes.
            result{n} = prodserver.mcp.internal.base64decode(contents.blob);
        end
    end
    
    if all(istext) && opts.TextAsString == true
        result = string(result);
    end
    
end

