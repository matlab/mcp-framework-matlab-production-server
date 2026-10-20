function tf = isOnPath(folder)
%isOnPath Which of the members of folder are on the MATLAB path?
%Compares absolute folder names, so a relative name, either kind of slash
%or a trailing separator still finds the path entry addpath would make.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        folder string
    end

    pth = canonical(string(strsplit(path, pathsep)));
    tf = arrayfun(@(f)ismember(canonical(absolute(f)), pth), folder);
end

function f = absolute(f)
% The absolute name of an existing folder, as addpath would store it. A
% folder that doesn't exist can't be on the path; leave its name alone.
    if isfolder(f)
        d = dir(f);
        f = string(d(1).folder);
    end
end

function f = canonical(f)
% Native separators, no trailing separator, and case-insensitive on
% Windows, where the file system is.
    f = replace(f, ["/","\"], filesep);
    f = strip(f, "right", filesep);
    if ispc
        f = lower(f);
    end
end
