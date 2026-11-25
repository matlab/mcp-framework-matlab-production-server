function result = uri2json(uri)
% Read data from a URI and return it as JSON.
% Checks registered MCP resources first, then reads from the URI
% scheme (file, http, etc.) using MarshallURI.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        uri (1,1) string % URI to read
    end
    arguments (Output)
        result (1,1) struct % Data from the URI
    end

    % Check registered MCP resources first.
    contents = prodserver.mcp.handler.resource.contents(uri);
    if ~isempty(contents)
        result = contents;
        return;
    end

    % Fall through to scheme-based reading via MarshallURI.
    mu = prodserver.mcp.io.MarshallURI();
    data = mu.deserialize(uri);
    if iscell(data) && isscalar(data)
        data = data{1};
    end

    % Numbers as a tool's output sends them: always an array, even of one
    % value, with NaN as null and Inf and -Inf as the text "Inf" and
    % "-Inf". result has no schema for data, and without one plain JSON
    % refuses Inf, and writes one value as a bare number.
    if isnumeric(data) && isreal(data)
        data = prodserver.mcp.jsonrpc.plainJSONValue(data, ...
            prodserver.mcp.jsonrpc.allowNonFiniteNumbers( ...
                struct("type", "array", "items", struct("type", "number"))));
    end

    result.data = data;
end
