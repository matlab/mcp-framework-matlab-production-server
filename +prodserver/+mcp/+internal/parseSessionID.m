function [id,realm,type,sid] = parseSessionID(id)
% parseSessionID Decompose a session id into its parts: 
%   SID:<type>:<realm>:<id>
% Return the parts in the order in which they are most
% likely to be used.

% Copyright (C) 2025, The MathWorks

    arguments
        id string { prodserver.mcp.validation.mustBeSessionID }
    end

    import prodserver.mcp.internal.Constants

    parts = split(id,Constants.SessionIDSep);

    sid = parts(1);
    type = parts(2);
    realm = parts(3);
    id = parts(4);

end