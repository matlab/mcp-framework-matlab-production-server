classdef Scope
% Scope The kinds of metric, as catalog.scope and catalog.filter(scope=)
% select them. A kind is read from the metric's name, never from the
% archive that reports it: each covers the whole instance. To select one
% archive's metrics, filter by archive too.
%
%   All is Instance, MCP and Custom, which don't overlap. MCP is
%   Framework, Server and Tool, which don't overlap either.

% Copyright 2026 The MathWorks, Inc.

    enumeration
        All       % Every metric on the MATLAB Production Server instance
        Instance  % MATLAB Production Server's own: matlabprodserver_*
        MCP       % The MCP framework's: Framework, Server and Tool
        Framework % MCP_Framework_Request, one per archive
        Server    % Each archive's MCP_<archive>_Request and _ElapsedTime
        Tool      % Each tool's MCP_<tool>_Call, _Rejected and _Refused,
                  % and their per-revision counts
        Custom    % Those deployed code reports itself: neither Instance
                  % nor MCP
    end
end
