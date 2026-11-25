classdef Level < uint8
%Level How much contract checking runs, by what a check may touch.
%
%   Levels are ordered, so a level includes every cheaper one:
%
%     None     no guarded checks; external preconditions still run
%     Memory   checks that read only in-memory state
%     Storage  also checks that read files or the store
%
%   A check site names the most expensive thing it touches, and
%   prodserver.mcp.contract.enforce(L) is true when the configured level is
%   at least L. Convention: AgentKnowledge practices/design-by-contract.md.
%
%   See also prodserver.mcp.contract.enforce, prodserver.mcp.contract.ensure

% Copyright 2026 The MathWorks, Inc.

    enumeration
        None    (0)
        Memory  (1)
        Storage (2)
    end
end
