function uri = percentDecode(uri)
%percentDecode Replace all percent-encodings in URI with their equivalent
%characters.
%
%   uri = percentDecode(uri) decodes each %XX sequence in a string array,
%   character vector or parseURI structure (its host, userInfo, path and
%   query). The sequences are UTF-8 bytes. A % not followed by two hex
%   digits is left as it is.

% Copyright 2022-2026 The MathWorks, Inc.

    if isstruct(uri)
        fields = ["host", "userInfo", "path", "query"];
        for n = 1:numel(uri)
            for f = fields
                [uri(n).(f)] = prodserver.mcp.io.percentDecode([uri(n).(f)]);
            end
        end
    elseif ischar(uri)
        uri = char(decode(string(uri)));
    elseif isstring(uri)
        for n = 1:numel(uri)
            uri(n) = decode(uri(n));
        end
    end
end

function s = decode(s)
% One pass, left to right, over the UTF-8 bytes. Each %XX becomes one byte
% and is never examined again, so %2541 decodes to the three characters
% %41, not to A. The bytes may form a multi-byte character, so convert back
% to text only at the end.
    if ismissing(s) || ~contains(s, "%")
        return
    end
    in = unicode2native(s, "UTF-8");
    out = zeros(size(in), "uint8");
    isHex = @(b) (b >= '0' & b <= '9') | (b >= 'A' & b <= 'F') | ...
        (b >= 'a' & b <= 'f');
    i = 1;
    k = 0;
    while i <= numel(in)
        k = k + 1;
        if in(i) == '%' && i + 2 <= numel(in) && ...
                isHex(in(i+1)) && isHex(in(i+2))
            out(k) = hex2dec(char(in(i+1:i+2)));
            i = i + 3;
        else
            out(k) = in(i);
            i = i + 1;
        end
    end
    s = string(native2unicode(out(1:k), "UTF-8"));
end
