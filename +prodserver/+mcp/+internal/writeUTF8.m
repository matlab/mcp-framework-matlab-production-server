function writeUTF8(file, lines, opts)
%writeUTF8 Write lines of text to a UTF-8 file.
%   writeUTF8(file, lines) writes each element of lines followed by the
%   platform's line ending, like writelines. A character row vector is one
%   line, and empty lines write a single line ending. Line endings within
%   an element are written as they are.
%
%   writeUTF8(file, lines, TrailingLineEnding=false) omits the line ending
%   after the last line, like writelines with
%   TrailingLineEndingRule="never".
%
%   writeUTF8(file, lines, Append=true) adds to the end of the file instead
%   of replacing it.
%
%   Unlike writelines, characters outside the Basic Multilingual Plane
%   survive: in R2026b writelines replaces them with U+001A even with
%   Encoding="UTF-8".
%
%See also: readUTF8

% Copyright 2026 The MathWorks, Inc.

    arguments
        file (1,1) string
        lines string
        opts.TrailingLineEnding (1,1) logical = true
        opts.Append (1,1) logical = false
    end

    if ispc
        eol = string([char(13) char(10)]);
    else
        eol = string(char(10));
    end

    if isempty(lines)
        lines = "";
    end
    text = join(lines(:), eol);
    if opts.TrailingLineEnding
        text = text + eol;
    end

    mode = "w";
    if opts.Append
        mode = "a";
    end
    fid = fopen(file, mode);
    if fid < 0
        error("prodserver:mcp:CannotOpenFile", ...
            "Could not open file %s for writing.", file);
    end
    closeFile = onCleanup(@() fclose(fid));
    fwrite(fid, unicode2native(text, "UTF-8"));
end
