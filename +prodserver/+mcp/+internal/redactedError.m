function err = redactedError(me)
%redactedError ME, with every URL in its message reduced by redactURI.
%   ERR = redactedError(ME) is an MException with ME's identifier and
%   message, in which each URL has lost its userinfo and query. MATLAB's
%   own transport errors (MATLAB:webservices:*) quote the address as given,
%   password included; a client function raises this in their place, so
%   code that tests the identifier still works. ME's causes are not kept:
%   they quote the same address.
%
%   See also prodserver.mcp.io.redactURI

% Copyright 2026 The MathWorks, Inc.

    msg = string(me.message);
    msg = regexprep(msg, "[A-Za-z][A-Za-z0-9+.-]*://[^\s'""<>]+", ...
        "${char(prodserver.mcp.io.redactURI(string($0)))}");
    id = me.identifier;
    if strlength(id) == 0
        err = MException("prodserver:mcp:TransportError", "%s", msg);
    else
        err = MException(id, "%s", msg);
    end
end
