function str = percentEncode(str,opts)
%percentEncode Replace characters with their percent encoding. 
%
%    str = percentEncode(str) replaces every character that is neither
%    unreserved (letters, digits and .-_~) nor a reserved URI delimiter
%    (/:?#[]@!$&'()*+,;=%) with the percent-encoding of its UTF-8 bytes.
%    A non-ASCII character is always encoded.
%
%    str = percentEncode(str,except=<string>) uses the ASCII characters in
%    <string> as the exceptions instead of the reserved URI delimiters.
%    skip=<string> adds to the exceptions; extra=<string> encodes the
%    characters in <string> even if they are exceptions or unreserved.
%    only=<string> clears the exceptions and encodes the characters in
%    <string> as well.
%
% Examples:
%
%    str = percentEncode("file:/path/with/s p a c e s/data.mat")


% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        str string
        opts.except (1,1) string = missing  % Do not encode these characters
        opts.only (1,1) string = missing    % Only encode these characters
        opts.extra (1,1) string = missing   % Add to encodable characters
        opts.skip (1,1) string = missing    % Add to unencodeable characters
    end

    unreserved = [ ...
        char( [double('A'):double('Z'), double('a'):double('z'), ...
              double('0'):double('9')] ) '.-_~' ];

    if ismissing(opts.except)
        except = "/:?#[]@!$&'()*+,;=%";
    else
        except = opts.except;
    end

    if ismissing(opts.skip) == false
        except = except + opts.skip;
    end

    extra = "";
    if ismissing(opts.extra) == false
        extra = opts.extra;
    end

    if ismissing(opts.only) == false
        extra = opts.only;
        except = "";
    end

    % A character is written as is if it is unreserved or an exception, and
    % not listed in extra. Every other character is percent-encoded.
    % Exceptions apply to ASCII characters only: anything else is always
    % encoded.
    keep = setdiff([unreserved, char(except)], char(extra));

    for n = 1:numel(str)
        if ismissing(str(n)) || strlength(str(n)) == 0
            continue
        end

        % Work on the UTF-8 bytes. A character outside the Basic
        % Multilingual Plane is two UTF-16 code units in MATLAB; encoding
        % each unit separately produces two invalid halves. Its four UTF-8
        % bytes encode correctly.
        bytes = unicode2native(str(n), "UTF-8");
        literal = bytes < 128 & ismember(char(bytes), keep);

        pieces = "%" + string(dec2hex(bytes, 2))';
        pieces(literal) = string(num2cell(char(bytes(literal))));
        str(n) = join(pieces, "");
    end
end

