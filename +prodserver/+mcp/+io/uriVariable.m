function name = uriVariable(uri)
%uriVariable Extract variable name from URI.

% Copyright 2024-2026 The MathWorks, Inc.

    

    u = prodserver.mcp.io.parseURI(uri);
    switch u.scheme
        case "file"
            % Extract variable from file:/path/to/<variable>[.<ext>]?
            slash = strfind(u.path,"/"); 
            if isempty(slash)
                error("prodserver:mcp:BadFileURI", ...
"Unrecognized URI %s. File URI must contain at least one forward " + ...
"slash followed by a file name.", u.path);
            end
            slash = slash(end);
            dot = strfind(u.path,".");
            if ~isempty(dot) && dot(end) > slash
                name = extractBetween(u.path, slash, dot(end), ...
                    Boundaries="exclusive");
            else
                name = extractAfter(u.path, slash);
            end
        case {"literal","json"}
             name = u.path;
        otherwise
            error("prodserver:mcp:SchemeNotImplemented", ...
                "Scheme %s not implemented.", u.scheme);
    end
end
