function out = fndProbe(op, value)
%fndProbe Deployed by tArchiveIsolation: act on archiveCache from inside an
%archive, and say which archive copy and worker answered.
%
%   OUT = fndProbe(OP, VALUE). OP is "set" or "get" on archiveCache, or
%   "setAppdata" or "getAppdata" on appdata(0) directly, to show what the
%   platform shares between archives. OUT is a struct: value (the entry,
%   or "<none>"), folder (deployedArchiveLocation().folderName) and pid (the
%   worker's process ID).

% Copyright 2026 The MathWorks, Inc.

    arguments
        op (1,1) string
        value = ""
    end
    import prodserver.mcp.handler.archiveCache
    name = "fndProbe";
    switch op
        case "set"
            archiveCache(name, action="set", value=value);
            v = value;
        case "get"
            v = archiveCache(name);
        case "setAppdata"
            setappdata(0, name, value);
            v = value;
        case "getAppdata"
            v = [];
            if isappdata(0, name)
                v = getappdata(0, name);
            end
        otherwise
            error("fndProbe:op", "Unknown op.");
    end
    if isempty(v)
        v = "<none>";
    end
    loc = prodserver.mcp.handler.deployedArchiveLocation();
    pid = -1;
    try
        pid = feature("getpid");
    catch
    end
    % char, not string: MPS's JSON gives a string scalar a type wrapper,
    % even in the small format, and a char row as a plain JSON string.
    out = struct("value", char(v), "folder", char(loc.folderName), "pid", pid);
end
