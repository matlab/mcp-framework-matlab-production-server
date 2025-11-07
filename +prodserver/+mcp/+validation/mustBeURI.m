function mustBeURI(x)
%mustBeURI Throw an exception iff x is not a valid URI.

% Copyright 2025, The MathWorks, Inc.
    
    if prodserver.mcp.validation.istext(x) == false
        error("prodserver:mcp:BadURIType", ...
  "Invalid URI type %s. URIs must be a string or character vector.", ...
            class(x));
    end

    tf = prodserver.mcp.validation.isuri(x);

    if any(tf) == false
        bad = x(~tf);
        error("prodserver:mcp:BadURI", "Invalid URI: %s", bad(1));
    end

end