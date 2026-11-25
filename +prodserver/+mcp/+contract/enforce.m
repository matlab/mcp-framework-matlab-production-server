function tf = enforce(level)
%enforce True when contract checks of LEVEL should run.
%
%   TF = prodserver.mcp.contract.enforce(LEVEL) compares LEVEL with the
%   configured level, read once per worker and cached:
%   - outside MPS (desktop, unit tests, CI): Memory;
%   - on an MPS worker (MPS_ENDPOINT_ROOT set): None;
%   - MW_MPS_MCP_CONTRACTS=None|Memory|Storage, in any case, overrides
%     either default.
%   A test sets the level with prodserver.mcp.test.mixin.ContractLevelFixture.
%
%     if prodserver.mcp.contract.enforce(prodserver.mcp.contract.Level.Memory)
%         prodserver.mcp.contract.ensure(os.State == "published", "publish: State");
%     end
%
%   See also prodserver.mcp.contract.Level, prodserver.mcp.contract.ensure

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query
%   Requires:  level is one Level value  (arguments: prodserver.mcp.contract.Level)
%   Ensures:   tf == (configuredLevel >= level); the same answer for the life of the worker
%              when off, the cost is one cached lookup
%              an unrecognized MW_MPS_MCP_CONTRACTS value is logged once and the default used
%   Raises:    none

    arguments
        level (1,1) prodserver.mcp.contract.Level
    end
    tf = prodserver.mcp.contract.internal.configuredLevel() >= level;
end
