function file = replaceStringsInFile(file, old, new)
% replaceStringsInFile Replace old with new in file.
%
%   The file is made writable if it is not already, and left as writable
%   afterwards. This check is necessary because some installs make all
%   installed files read-only -- and prodserver.mcp.build treats some of
%   those files as templates, which it copies and modifies.

% Copyright 2025-2026 The MathWorks, Inc.

    content = prodserver.mcp.internal.readUTF8(file);
    content = replace(content, old, new);
    
    try
        prodserver.mcp.internal.writeUTF8(file, content);
    catch writeErr
        % Make writable for this user.
        args = {"+w"};
        if ~ispc, args = [args {"u"}]; end
        [ok, msg] = fileattrib(file, args{:}); %#ok<FILEATTRIB>
        if ~ok
            err = MException("prodserver:mcp:FileNotWritable", ...
                "Unable to make ""%s"" writable (%s), so it cannot be " + ...
                "updated. Make the file writable and try again.", ...
                file, strip(string(msg)));
            throw(addCause(err, writeErr));
        end
        % The attribute was the problem, or it wasn't. Either way, a second
        % failure here is not about the read-only flag, so let it through.
        prodserver.mcp.internal.writeUTF8(file, content);
    end
end
