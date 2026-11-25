classdef Event
%Event The identifiers of the foundation's own log events.
%
%   Each feature keeps its events in its own package, and Log accepts any
%   prodserver:mcp:<Name> identifier, so nothing here lists a feature's
%   events.
%
%     LogSeverityUnavailable  main_config on an MPS instance is missing or
%                             unreadable, or its --log-severity is not a
%                             level name; once per Log
%     ContractLevelUnknown    MW_MPS_MCP_CONTRACTS names no contract level
%     RequestCancelled        a notifications/cancelled arrived
%
%   See also prodserver.mcp.logging.Log

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        LogSeverityUnavailable = "prodserver:mcp:LogSeverityUnavailable"
        ContractLevelUnknown = "prodserver:mcp:ContractLevelUnknown"
        RequestCancelled = "prodserver:mcp:RequestCancelled"
    end
end
