function [folder,archFolder] = packageFolder
%packageFolder Return the package's root folder, and the 
%architecture-specific bin directory.

% Copyright 2025 The MathWorks, Inc.

    folder = fileparts(mfilename("fullpath"));
    folder = strrep(folder,fullfile("+prodserver","+mcp","+internal"),"");
    
    archFolder = fullfile(folder,"bin",computer("arch"));
end