function name = archiveNameOf(folder)
%archiveNameOf The archive a deployment folder holds.
%
%   NAME = archiveNameOf(FOLDER) is FOLDER without its _<n> suffix, where
%   MPS deploys archive <archive> into the folder <archive>_<n>, and "" for
%   a folder with no such suffix. FOLDER is a string array, and NAME has
%   its size. The one place the folder rule is written: deployedArchiveLocation
%   names this deployment's archive with it, and archiveCache's eviction
%   finds an archive's other versions with it.
%
%   See also prodserver.mcp.handler.deployedArchiveLocation

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  folder is a string array  (internal)
%   Ensures:   each element of name is "" or its folder with a final _<digits> removed
%   Raises:    none

    name = regexprep(folder, "^(.+)_\d+$", "$1");
    name(name == folder) = "";
end
