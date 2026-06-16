function mustBeHostName(str)
%mustBeHostName Error if str is a syntatically invalid host name.

% Copyright 2025, The MathWorks, Inc.

    % First gate.
    mustBeTextScalar(str);
    str = lower(string(str));

    % ASCII letters a-z (case insensitive), numbers, dot, and hyphen. 
    % Generally follow RFC 1178.

    % List the allowed characters. Count how many there are in the string.
    % N must be exactly equal to the string length.

    hostCharacters = (lettersPattern(1) | digitsPattern(1) | "." | "-" );
    n = count(str,hostCharacters);
    if n ~= strlength(str)
        error("prodserver:mcp:BadHostName", ...
            "Host name must contain only ASCII letters, digits, dots and " + ...
            "hyphens. %s contains at least one character not in that list.", ...
            str);
    end
end
