function str = sanitizeForURI(str)
%sanitizeForURI Make a string safe to use as part of a URI. Convert all
%reserved characters to underscore.

% Copyright 2022-2026 The MathWorks, Inc.

    str = replace(str, prodserver.mcp.internal.Constants.InvalidInURI, "_");

end
