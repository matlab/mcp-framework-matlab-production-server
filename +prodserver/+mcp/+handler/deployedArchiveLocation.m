function loc = deployedArchiveLocation(opts)
%deployedArchiveLocation Which deployed archive this code runs in, and where.
%
%   LOC = prodserver.mcp.handler.deployedArchiveLocation() returns a struct:
%     instanceRoot  the MPS instance folder: when endpointRoot is set (an MPS
%                   worker), the first of fileparts(endpointRoot) and the
%                   current folder that holds config/main_config; "" otherwise.
%                   MPS sets MPS_ENDPOINT_ROOT on its workers, and a worker's
%                   current folder is the instance root.
%     folderName    <archive>_<n>, the last part of ctfRoot. On a worker,
%                   ctfroot is <extract-root>/.mps_deployed/<archive>_<n>.
%     archiveName   folderName without the _<n> suffix; "" when folderName
%                   has no such suffix (outside MPS).
%   archiveCache and Log.instance() (to find main_config) call it. Tests
%   inject through endpointRoot= and ctfRoot=.
%
%   See also prodserver.mcp.handler.archiveCache

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  none
%   Ensures:   folderName is the last part of ctfRoot
%              archiveName is "" or folderName with its _<n> suffix removed
%              instanceRoot is "" or a folder that holds config/main_config
%   Raises:    none

    arguments
        opts.endpointRoot (1,1) string = getenv("MPS_ENDPOINT_ROOT")
        opts.ctfRoot (1,1) string = ctfroot
    end

    [~, folder, ext] = fileparts(strip(opts.ctfRoot, "right", filesep));
    loc.instanceRoot = "";
    loc.folderName = folder + ext;
    loc.archiveName = prodserver.mcp.handler.internal.archiveNameOf(loc.folderName);
    if strlength(opts.endpointRoot) > 0
        for candidate = [string(fileparts(strip(opts.endpointRoot, "right", filesep))), string(pwd)]
            if isfile(fullfile(candidate, "config", "main_config"))
                loc.instanceRoot = candidate;
                break
            end
        end
    end
end
