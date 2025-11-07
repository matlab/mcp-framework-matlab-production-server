function file = replaceStringsInFile(file, old, new)
% replaceStringsInFile Replace old with new in file.

% Copyright 2025, The MathWorks, Inc.

    content = fileread(file);
    content = replace(content, old, new);
    writelines(content,file);
end
