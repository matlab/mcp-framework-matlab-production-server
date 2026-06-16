function tf = isOnPath(folder)
%isOnPath Which of the members of folder are on the MATLAB path?

% Copyright 2025, The MathWorks, Inc.

    arguments
        folder string
    end

     pth = strsplit(path, pathsep);
     tf = ismember(folder,pth);
end