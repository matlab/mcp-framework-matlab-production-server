function str = sanitizeForURI(str)
%santiziseForURI Make a string safe to use as part of a URI. Convert all
%reserved characters to underscore.

% Copyright (C) 2025, The MathWorks, Inc.

    reserved = ":/?#[]@!$&'()*+,;=";
    str = strrep(str,reserved,"_");
end
