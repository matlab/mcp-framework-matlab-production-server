function text = readUTF8(file, opts)
%readUTF8 Read a UTF-8 text file.
%   text = readUTF8(file) returns the file's text as a character row
%   vector, like fileread. Line endings are kept as they are. An empty file
%   gives a 0x0 character array.
%
%   lines = readUTF8(file, Lines=true) returns a string column with one
%   element per line, like readlines: \r\n, \n and \r all end a line, and a
%   final line ending gives a final "".
%
%   Unlike fileread and readlines, characters outside the Basic
%   Multilingual Plane survive: in R2026b those functions replace them
%   with U+001A even with Encoding="UTF-8". A leading byte order mark is
%   removed.
%
%See also: writeUTF8

% Copyright 2026 The MathWorks, Inc.

    arguments
        file (1,1) string
        opts.Lines (1,1) logical = false
    end

    fid = fopen(file, "r");
    if fid < 0
        error("prodserver:mcp:CannotOpenFile", ...
            "Could not open file %s.", file);
    end
    closeFile = onCleanup(@() fclose(fid));
    bytes = fread(fid, inf, "*uint8")';

    if numel(bytes) >= 3 && isequal(bytes(1:3), uint8([239 187 191]))
        bytes = bytes(4:end);
    end

    if isempty(bytes)
        text = char.empty;
    else
        text = native2unicode(bytes, "UTF-8");
    end

    if opts.Lines
        cr = char(13);
        lf = char(10);
        text = replace(string(text), [cr lf], lf);
        text = replace(text, cr, lf);
        text = split(text, lf);
    end
end
