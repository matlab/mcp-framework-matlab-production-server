function level = configuredLevel(newLevel)
%configuredLevel The contract level of this process, read once and cached.
%
%   LEVEL = configuredLevel() returns the cached level, reading it on the
%   first call: MW_MPS_MCP_CONTRACTS if it names a level, in any case;
%   otherwise None on an MPS worker (MPS_ENDPOINT_ROOT is set) and Memory
%   everywhere else. An unrecognized MW_MPS_MCP_CONTRACTS value is logged
%   as prodserver.mcp.logging.Event.ContractLevelUnknown, at Warning, and
%   the default is used. Log must use no contract check, so reading the
%   level never recurses: an enforce call anywhere on Log's path would
%   call back here before the level is cached.
%
%   configuredLevel(LEVEL) sets the cached level, and configuredLevel([])
%   forgets it, so the next call reads the environment again. They are the
%   test seam behind prodserver.mcp.test.mixin.ContractLevelFixture.
%
%   See also prodserver.mcp.contract.enforce

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      command (caches the level; logs an unrecognized value)
%   Requires:  newLevel, when given, is [] or names a Level  (internal; ContractLevelFixture)
%   Ensures:   level is a Level; after configuredLevel([]) the next call reads the environment
%              an unrecognized MW_MPS_MCP_CONTRACTS value is logged once and the default used
%   Raises:    none

    persistent cached
    if nargin > 0
        if isempty(newLevel)
            cached = [];
        else
            cached = prodserver.mcp.contract.Level(newLevel);
        end
        level = cached;
        return
    end
    if isempty(cached)
        cached = readLevel();
    end
    level = cached;
end

function level = readLevel()
    import prodserver.mcp.contract.Level
    if strlength(getenv("MPS_ENDPOINT_ROOT")) > 0
        level = Level.None;
    else
        level = Level.Memory;
    end
    requested = strip(string(getenv("MW_MPS_MCP_CONTRACTS")));
    if strlength(requested) == 0
        return
    end
    names = string(enumeration("prodserver.mcp.contract.Level"));
    k = strcmpi(names, requested);
    if any(k)
        level = Level(names(k));
    else
        prodserver.mcp.logging.Log.instance().log( ...
            prodserver.mcp.logging.Level.Warning, ...
            prodserver.mcp.logging.Event.ContractLevelUnknown, ...
            "MW_MPS_MCP_CONTRACTS is %s, which is not %s. Using %s.", ...
            prodserver.mcp.protocol.echo(requested), join(names, ", "), string(level));
    end
end
