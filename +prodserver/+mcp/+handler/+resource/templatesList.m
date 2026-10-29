function [result, httpCode, httpMsg, msgHeaders] = templatesList(jrpc, ~)
%templatesList Handle MCP resources/templates/list request. The resources
%   capability is advertised, so this must return a well-formed (possibly
%   empty) resourceTemplates array -- never an empty 204 for an id-bearing
%   request. The framework does not yet model URI templates, so the array is
%   empty.

% Copyright 2026 The MathWorks, Inc.

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    r.resourceTemplates = {};
    result.result = r;
end
