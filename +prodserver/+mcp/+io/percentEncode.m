function str = percentEncode(str,opts)
%percentEncode Replace characters with their percent encoding. 
%
%    str = percentEncode(str) replaces all non-ASCII characters with their
%    percent-encoding. 
%
%    str = percentEncode(str,except=<string>) does not percent-encode any
%    of the characters in <string>.
%
% Examples:
%
%    str = percentEncode("file:/path/with/s p a c e s/data.mat")


% Copyright 2025, The MathWorks, Inc.

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

    % There's a lot of back and forth between row and column vectors and
    % character vectors and strings. Mostly that's because MATLAB's string
    % arrays don't allow indexing into individual strings. To manipulate a
    % string at the character level, it must be converted to a character
    % vector. (And then back again, to preserve its original datatype.)

    untouchable = char(except);
    extra = char(extra);
    for n = 1:numel(str)

        % Find the non-unreserved characters in the string. MATLAB uses 
        % UTF-16, which guarantees that the ASCII characters have numeric 
        % values < 128. (UTF-8 uses a multi-byte encoding which cannot 
        % make any such guarantee.)
        c = char(str(n));
        encodable = unique(c(~ismember(c,unreserved)));

        %nonASCII = double(c) > 128;
        %encodable = char(c(nonASCII));

        % Remove untouchable characters from encodable
        encodable = setdiff(encodable,untouchable);

        % Add extra characters to encodable
        encode = [ encodable, char(extra) ];

        % If encodable is empty, replace will add a % between every
        % character in the string. Nobody wants that. 
        if isempty(encode), continue; end

        % Replace requires a column vector.
        if isrow(encode), encode = encode'; end

        % Percent encode all the encodable and non-ASCII characters. Expand
        % UTF-16 characters into their multi-byte UTF-8 representation to
        % ensure that the % is followed by exactly two hex digits.
        %
        % encoding will be a string vector the same length as encode. But
        % each string in encoding will have at least 3 characters and
        % possibly as many as 12. (UTF-8 characters range from 1 to 4 bytes
        % in size, and each byte is percent-encoded into three characters.)
        encoding = arrayfun(@(c)strjoin("%"+string(dec2hex(...
            unicode2native(c,"UTF-8"))),''),encode);

        % Here encodable must be a string (a column vector of 1x1 strings
        % -- each a single character) or replace will error.
        str(n) = replace(str(n),string(encode),encoding);
    end
end

