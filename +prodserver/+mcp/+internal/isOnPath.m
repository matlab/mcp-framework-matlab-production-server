function tf = isOnPath(folder)
%isOnPath Which of the members of folder are on the MATLAB path?
%Compares absolute folder names, so a relative name, either kind of slash
%or a trailing separator still finds the path entry addpath would make.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        folder string
    end

    import prodserver.mcp.internal.canonicalFolder

    pth = canonicalFolder(string(strsplit(path, pathsep)), resolve=false);
    tf = ismember(canonicalFolder(folder), pth);
end
