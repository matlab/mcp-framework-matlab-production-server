function mustBeScheme(str)
%mustBeScheme Error if str does not conform to HTTP scheme syntax.

% Copyright 2025, The MathWorks, Inc.

    validateattributes(str, {'char','string'}, {'scalartext','nonempty'});
    str = lower(string(str));

    % ASCII letters a-z (case insensitive), numbers, plus, dot, and hyphen. 
    % Generally follow RFC 3986.

    % List the allowed characters. Count how many there are in the string.
    % N must be exactly equal to the string length.

    hostCharacters = (lettersPattern(1) | digitsPattern(1) | "+" | "." | "-" );
    n = count(str,hostCharacters);
    if n ~= strlength(str)
        error("prodserver:mcp:BadScheme", ...
            "Scheme name must contain only ASCII letters, digits, '.', " + ...
            "'-' and '+'. %s contains at least one character not in that " + ...
            "list.", str);
    end

    % Scheme must begin with a letter.
    if startsWith(str,lettersPattern(1)) == false
        error("prodserver:mcp:BadScheme", ...
            "Invalid scheme: %s. Schemes must begin with an ASCII letter.", ...
            str);
    end
end
