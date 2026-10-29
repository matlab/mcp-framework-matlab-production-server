function value = importJSON(uri,type,config,opts)
%importJSON Convert a JSON-scheme URI into a MATLAB data value. Expect the
%URI as a structure with at least fields scheme, path and query. Pay no
%attention to presence or absence of other fields.
%
%    VALUE = importJSON(URI, TYPE, CONFIG, import=OPTS)
%
%has the signature MarshallURI.reader uses for every scheme's read
%function. TYPE, CONFIG and the import option are accepted and ignored:
%the JSON in the query determines the value, and JSON has no import
%options.
%
%For any given JSON-serializable MATLAB value:
%
%    value == importJSON(exportJSON(value))

% Copyright 2024-2026 The MathWorks, Inc.

    arguments
        uri
        type = []
        config = []
        opts.import = []
    end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.io.parseURI
    import prodserver.mcp.validation.istext
    
    import prodserver.mcp.internal.isnothing

    % Allow text input, if convertible to URI structure.
    if istext(uri)
        uri = parseURI(uri);
    end

    if hasField(uri,"scheme") 
        if strcmpi(uri.scheme,"json")
            if hasField(uri,"query") && hasField(uri,"path")
                % The query field should be a JSON string.
                json = uri.query;
                if isnothing(json)
                    error("prodserver:mcp:NoJSONQuery", ...
            "Unable to find JSON string in query of URI %s.", uri);
                end
                value = prodserver.mcp.io.fromJSON(json); 
            else
                if hasField(uri,"query") == false
                    error("prodserver:mcp:URIMissingQuery", ...
                        "Query missing from URI %s.", uri);
                end
                if hasField(uri,"path") == false
                    error("prodserver:mcp:URIMissingPath", ...
                        "Path missing from URI %s.", uri);
                end
            end
        else
            error("prodserver:mcp:ExpectedJSONScheme", ...
               "JSON URI %s must begin with scheme 'json:'", uri);
        end
    else
        error("prodserver:mcp:URIMissingScheme", ...
            "Scheme missing from URI %s.", uri);
    end
end
