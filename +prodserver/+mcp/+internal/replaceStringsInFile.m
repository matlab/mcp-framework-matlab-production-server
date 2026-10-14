function file = replaceStringsInFile(file, old, new)
% replaceStringsInFile Replace old with new in file.
%
%   The file is made writable first if it is not already. build copies the
%   routes templates out of the installed package, and copyfile keeps the
%   source's attributes, so the copy is read-only whenever the install is.

% Copyright 2025-2026 The MathWorks, Inc.

    content = fileread(file);
    content = replace(content, old, new);
    
    try
        writelines(content, file);
    catch writeErr
        [ok, msg] = fileattrib(file, "+w"); %#ok<FILEATTRIB>
        if ~ok
            err = MException("prodserver:mcp:FileNotWritable", ...
                "Unable to make ""%s"" writable (%s), so it cannot be " + ...
                "updated. Make the file writable and try again.", ...
                file, strip(string(msg)));
            throw(addCause(err, writeErr));
        end
        % The attribute was the problem, or it wasn't. Either way, a second
        % failure here is not about the read-only flag, so let it through.
        writelines(content, file);
    end
end
