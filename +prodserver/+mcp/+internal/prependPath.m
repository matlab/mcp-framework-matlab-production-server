function prependPath(folder)
%prependPath Put folder at the front of the MATLAB path, unless it belongs
%to an installed package and is already on the path. MATLAB warns when a
%package's folders are moved one at a time, and an installed package's
%folders are already where MATLAB wants them. Callers must save the path
%before calling prependPath and restore it afterwards.

% Copyright 2026 The MathWorks, Inc.

    arguments
        folder (1,1) string
    end

    import prodserver.mcp.internal.isOnPath
    import prodserver.mcp.internal.isInstalledPackageFolder

    if isOnPath(folder) && isInstalledPackageFolder(folder)
        return;
    end
    addpath(folder);
end
