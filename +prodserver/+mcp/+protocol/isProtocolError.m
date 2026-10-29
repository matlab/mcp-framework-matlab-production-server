function tf = isProtocolError(me)
%isProtocolError True for MCP errors that may indicate a stale cached protocol.

% Copyright 2026 The MathWorks, Inc.

    % RemoteError must be listed: requireSuccess now parses a JSON-RPC error
    % body at any failing status, so a stale cached protocol surfaces as
    % RemoteError (an id-bearing -32020/-32022/-32601) where it previously
    % surfaced as a bare HttpError. Without this arm the cache-clear-and-retry
    % in exist.m, list.m, call.m and read.m silently stops firing.
    %
    % ServerError (a 5xx with no JSON-RPC error) is deliberately absent: the
    % server may have failed after the tool ran, and the retry in call.m
    % would run it again. ToolError and JsonRpcError are absent likewise.
    id = me.identifier;
    tf = contains(id, "HttpError") || ...
         contains(id, "RemoteError") || ...
         contains(id, "UnattributableRequest") || ...
         contains(id, "NoSessionFromServer") || ...
         contains(id, "MethodNotFound");
end
