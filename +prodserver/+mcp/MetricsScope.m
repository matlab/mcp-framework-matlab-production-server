classdef MetricsScope
% MetricsScope The names of the available metrics sets.

% Copyright 2026 The MathWorks, Inc.

    enumeration
        All      % All metrics on the MATLAB Production Server instance
        Instance % 
        MCP      % All MCP metrics
        Server   % Tool server (archive) metrics only
        Tool     % Metrics for the given tool only
    end 
end