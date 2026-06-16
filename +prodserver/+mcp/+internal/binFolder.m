function [bin,ctf] = binFolder(varargin)
%toolboxBinDir Folder where component-specific binaries are installed.
% Specify component path sections in varargin.

% Copyright 2025 The MathWorks, Inc.

    rootFolder = prodserver.mcp.internal.packageFolder;

    % Use the path to this folder to find the toolbox part of the bin
    % folder -- that's the part between the root folder and the first
    % folder that starts with a +.
    tbx = fileparts(mfilename("fullpath"));
    tbx = erase(tbx,rootFolder);
    if isdeployed
        % Deployed MATLAB functions sometimes have an /mcr/ in their
        % file path that we must eliminate, as it never appears in the
        % deployed path to binaries.
        tbx = erase(tbx,string(filesep)+"mcr"+string(filesep));
    end
    tbx = extractBefore(tbx,"+prodserver");
    
    binFolder = fullfile("bin",computer("arch"),tbx,varargin{:});
    bin = fullfile(rootFolder,binFolder);

    if nargout > 1
        ctf = fullfile(ctfroot,binFolder);
    end
end