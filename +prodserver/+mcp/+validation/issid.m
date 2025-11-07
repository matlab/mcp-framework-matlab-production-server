function tf = issid(x)
%issid Is X a Session-ID? 

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.internal.Constants

    tf = isempty(x) == false && ...
        prodserver.mcp.validation.istext(x);

    if tf
        prefix = Constants.SessionIDPrefix + Constants.SessionIDSep + ...
            Constants.SessionIDType;
        tf = startsWith(x,prefix) && count(x,Constants.SessionIDSep) == 3;
    end
end