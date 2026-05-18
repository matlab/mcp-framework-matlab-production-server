function mustBeHost(x)
% mustBeHost X must be either a host name or a server address.

% Copyright 2026, The MathWorks, Inc.

    try
        prodserver.mcp.validation.mustBeHostName(x);
    catch me
        if strcmpi(me.identifier,"prodserver:mcp:BadHostName")
            prodserver.mcp.validation.mustBeServer(x);
        else
            rethrow(me);
        end
    end

end
