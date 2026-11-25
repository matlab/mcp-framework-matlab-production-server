function mustNotBeReservedToolName(name, kind)
% mustNotBeReservedToolName Error if any element of NAME is the name of one
% of the framework's own tools: read_mcp_resource, which every server has,
% or uri2json, which a server built with an MCP App has.
%
%   mustNotBeReservedToolName(name) checks tool names: build's 'tool'
%   option.
%
%   mustNotBeReservedToolName(name, "function") checks the functions build
%   is given, by base name, so a path such as "src/uri2json.m" counts.
%
%   Tools are found by name. A user tool with one of these names would
%   either collide with the framework's (AmbiguousToolName on every call)
%   or, on a server without an app, be hidden from and refused to every
%   client that doesn't support MCP Apps, as uri2json is. A function with
%   one of these names can't be built under another tool name either:
%   build puts the framework's tools first on the path, so it would find
%   and build the framework's function in place of the user's.

% Copyright 2026 The MathWorks, Inc.

    arguments
        name string
        kind (1,1) string {mustBeMember(kind, ["tool", "function"])} = "tool"
    end

    import prodserver.mcp.MCPConstants

    reserved = [MCPConstants.ReadResourceTool, MCPConstants.Uri2JsonTool];
    names = name(:)';
    if kind == "function"
        names = string(arrayfun(@baseName, names, UniformOutput=false));
    end
    taken = intersect(names, reserved, "stable");
    if isempty(taken)
        return
    end

    if kind == "function"
        msg = sprintf("Function name '%s' is reserved: the framework's " + ...
            "own tools are named %s, and build would find the " + ...
            "framework's function in place of yours. Rename the " + ...
            "function.", taken(1), prodserver.mcp.internal.andList(reserved));
    else
        msg = sprintf("Tool name '%s' is reserved: the framework's own " + ...
            "tools are named %s. Choose another name with the 'tool' " + ...
            "option.", taken(1), prodserver.mcp.internal.andList(reserved));
    end
    throwAsCaller(MException("prodserver:mcp:ReservedToolName", "%s", msg));
end

function n = baseName(f)
    [~, n] = fileparts(f);
end
