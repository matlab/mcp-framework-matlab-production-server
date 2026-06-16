function mustBeSessionID(x)
%mustBeSessionID Error if X is not a session ID.

% Copyright 2025, The MathWorks, Inc

    import prodserver.mcp.internal.Constants

    if prodserver.mcp.validation.istext(x) == false
        error("prodserver:mcp:BadSessionIDType", ...
            "Unexpected type %s for session ID. Session ID must be " + ...
            "scalar string or char vector.", class(x));
    end

    if prodserver.mcp.validation.issid(x) == false
        prefix = Constants.SessionIDPrefix + Constants.SessionIDSep + ...
            Constants.SessionIDType;
        error("prodserver:mcp:MalformedSessionID",...
            "Session ID %s does not conform to MathWorks format. Verify " + ...
            "that session ID begins with %s.", ...
            x,prefix);
    end
end