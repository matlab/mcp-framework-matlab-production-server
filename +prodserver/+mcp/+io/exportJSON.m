function json = exportJSON(uri,value,config)
%exportJSON Convert MATLAB value to JSON. Value may be any type
%recognized by jsonencode. Value may not be a MATLAB Object, but it may be
%a cell array or structure, provided the container type does not contain
%any MATLAB Objects.
%
%For any given JSON-serializable MATLAB value:
%
%    value == importJSON(exportJSON(name,value))

% Copyright 2024-2025 The MathWorks, Inc.

    if prodserver.mcp.validation.istext(uri)
        u = prodserver.mcp.io.parseURI(uri);
    elseif isstruct(uri)
        u = uri;
    end
    if strcmpi(u.scheme,"json") == false
        error("prodserver:mcp:UnexpectedScheme", ...
   "Unexpected scheme 'json:' in URI %s. URI must begin with scheme %s.", ...
               uri, u.scheme);
    end
    if ~isvarname(u.path)
        error("prodserver:mcp:BadVariableName", ...
            "Invalid variable name syntax %s.", uri);
    end
    json = prodserver.mcp.io.toJSON(value);
end