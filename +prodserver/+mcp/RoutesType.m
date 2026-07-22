classdef RoutesType
% Location for MATLAB Production Server routes files.
    
% Copyright 2025-2026 The MathWorks, Inc.

    enumeration
        Archive    % Place routes file in archive
        DevAndTest % Routes file for MATLAB-hosted Production Server
        Instance   % Generate global routes for the given archive
    end
end