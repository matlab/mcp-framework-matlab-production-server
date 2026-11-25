function value = archiveCache(name, opts)
%archiveCache The per-archive cache behind the worker's caches.
%
%   VALUE = prodserver.mcp.handler.archiveCache(NAME, action=, value=,
%   ctfRoot=) is the one helper behind the caches a deployed archive keeps
%   between requests. Actions:
%     "get"       the entry, or [] when there is none
%     "set"       store VALUE, and remove NAME's entries for other versions
%                 of the same archive
%     "clear"     remove the entry
%     "clearAll"  remove NAME's entries for every archive and version
%
%   An entry lives in a persistent cell array in this function, found
%   through a dictionary of its positions: a dictionary holding the values
%   themselves takes time that grows with a value's nested parts, about 180
%   microseconds for a 200-tool definition struct, while a cell element is
%   returned in about 1 (measured, R2026b). MPS resolves functions per
%   archive, so each deployed archive has its own copy of the cache, and a
%   hot redeploy starts with an empty one (measured).
%
%   The key is NAME + "/" + the deployment's folderName
%   (deployedArchiveLocation). Neither a MATLAB name nor a folder name can
%   hold a "/", so the key is unambiguous and both parts read back exactly:
%   "x" in archive "a_b_1" and "x_a" in archive "b_1" never share a key,
%   and "clearAll" of "x" never touches "x_y". The deployment's location and
%   each name's key are computed once and kept, so a hit calls no ctfroot,
%   no deployedArchiveLocation and no appdata function. Eviction on "set"
%   does nothing on MPS, where each copy holds only its own archive's
%   entries; it keeps its meaning for tests that act as two deploys.
%
%   Nothing is shared between the archives in a worker. No MATLAB state
%   was found that is: appdata(0), like a persistent variable, belongs to
%   one deployed archive copy, and a hot redeploy loses it (measured on
%   R2026b, with and without MW_MULTIMCOS_MODE).
%
%   ctfRoot= (tests) stands in for ctfroot. "" (default) means this
%   deployment; any other value is used as given, bypassing the kept
%   location.
%
%   A failed load is never cached: callers "set" only after a success.
%   "clear functions" in desktop MATLAB empties the cache, so the
%   next request reloads.
%
%   See also prodserver.mcp.handler.deployedArchiveLocation

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      command ("get" is a query)
%   Requires:  name is a valid MATLAB name  (internal)
%   Ensures:   "get" returns what the last "set" for this archive stored, or []
%              after "set", no entry of NAME for another version of this archive remains
%              after "clear", "get" returns []; after "clearAll", no entry of NAME remains
%              in the calling copy
%              a steady-state "get" calls no ctfroot, deployedArchiveLocation or appdata
%              function, and its cost does not grow with the value
%   Raises:    none

    arguments
        name (1,1) string
        opts.action (1,1) string {mustBeMember(opts.action, ["get", "set", "clear", "clearAll"])} = "get"
        opts.value = []
        opts.ctfRoot (1,1) string = ""
    end

    % slot: key -> position in stored. keyOf: name -> this deployment's key.
    persistent here slot stored keyOf
    if isempty(slot)
        slot = configureDictionary("string", "double");
        stored = {};
        keyOf = configureDictionary("string", "string");
    end

    value = [];
    if opts.action == "clearAll"
        all = keys(slot);
        [slot, stored] = drop(slot, stored, all(extractBefore(all, "/") == name));
        return
    end

    % The key: this deployment's, kept per name; or the given root's.
    if strlength(opts.ctfRoot) == 0
        if isKey(keyOf, name)
            key = keyOf(name);
        else
            if isempty(here)
                here = prodserver.mcp.handler.deployedArchiveLocation();
            end
            key = name + "/" + here.folderName;
            keyOf(name) = key;
        end
        where = here;
    else
        where = prodserver.mcp.handler.deployedArchiveLocation(ctfRoot=opts.ctfRoot);
        key = name + "/" + where.folderName;
    end

    switch opts.action
        case "get"
            if isKey(slot, key)
                value = stored{slot(key)};
            end
        case "set"
            if strlength(where.archiveName) > 0
                % Earlier versions of this archive: the same name, and a
                % folder that holds the same archive.
                all = keys(slot);
                mine = all(extractBefore(all, "/") == name);
                same = prodserver.mcp.handler.internal.archiveNameOf( ...
                    extractAfter(mine, "/")) == where.archiveName;
                [slot, stored] = drop(slot, stored, mine(same & mine ~= key));
            end
            if isKey(slot, key)
                stored{slot(key)} = opts.value;
            else
                free = find(~ismember(1:numel(stored), values(slot)), 1);
                if isempty(free)
                    free = numel(stored) + 1;
                end
                stored{free} = opts.value;
                slot(key) = free;
            end
        case "clear"
            [slot, stored] = drop(slot, stored, key);
    end
end

function [slot, stored] = drop(slot, stored, names)
% Remove the keys NAMES; their positions are free for the next new key.
    for k = reshape(string(names), 1, [])
        if isKey(slot, k)
            stored{slot(k)} = [];
            slot = remove(slot, k);
        end
    end
end
