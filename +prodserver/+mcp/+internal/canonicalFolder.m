function f = canonicalFolder(f, opts)
%canonicalFolder Folder names in a form that compares equal when they name
%the same folder: absolute, native separators, no trailing separator, and
%lower case on Windows and macOS, whose file systems ignore case by
%default. A folder that doesn't exist, or can't be read, keeps its name,
%apart from separators and case.

% Copyright 2026 The MathWorks, Inc.

    arguments
        f string
        % Resolve relative names to absolute ones? Names on the MATLAB
        % path are already absolute; skip the file system lookups for them.
        opts.resolve (1,1) logical = true
    end

    if opts.resolve
        for n = 1:numel(f)
            f(n) = absolute(f(n));
        end
    end
    f = replace(f, ["/","\"], filesep);
    f = strip(f, "right", filesep);
    if ispc || ismac
        f = lower(f);
    end
end

function f = absolute(f)
% The absolute name of an existing folder, as addpath would store it.
    if isfolder(f)
        d = dir(f);
        if ~isempty(d)
            f = string(d(1).folder);
        end
    end
end
