function [result, httpCode, httpMsg, msgHeaders] = initialized(~)
%initialized Handle MCP notifications/initialized notification.
%   Returns 202 Accepted with no response body per the MCP specification.

% Copyright 2025-2026 The MathWorks, Inc.

    httpCode = 202;
    httpMsg = 'Accepted';
    msgHeaders = {};
    result = [];
end
