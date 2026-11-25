classdef RequestContext
%RequestContext What is known about the request a handler is serving.
%   The protocol adapter builds one per request and passes it, through the
%   dispatcher, to every handler. Handlers read per-request facts from it
%   rather than working them out from the body: only the adapter knows which
%   revision is serving the request, and where that revision keeps the
%   client's capabilities.
%
%   ctx = RequestContext(version) is a request served by protocol revision
%   VERSION from a client that declared no capabilities.
%
%   ctx = RequestContext(version, Capabilities=caps, ClientInfo=info) adds
%   the client's capabilities (a ClientCapabilities) and its name and
%   version, as the client sent them.
%
%   Properties are added as handlers need them. A storage scope for
%   session-bound data is the likely next one; it is deliberately not the
%   session ID, which 2026-07-28 requests don't have.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = immutable)
        % The protocol revision serving the request, such as "2025-06-18".
        % Not necessarily the version the request stated: an alias such as
        % 2024-11-05 is served by 2025-06-18.
        Version (1,1) string

        % What the client declared it supports.
        Capabilities (1,1) prodserver.mcp.protocol.ClientCapabilities = ...
            prodserver.mcp.protocol.ClientCapabilities.none()

        % The client's name and version, as decoded, or [] if it sent none.
        ClientInfo = []
    end

    methods
        function ctx = RequestContext(version, opts)
            arguments
                version (1,1) string {mustBeNonzeroLengthText}
                opts.Capabilities (1,1) prodserver.mcp.protocol.ClientCapabilities = ...
                    prodserver.mcp.protocol.ClientCapabilities.none()
                opts.ClientInfo = []
            end
            ctx.Version = version;
            ctx.Capabilities = opts.Capabilities;
            ctx.ClientInfo = opts.ClientInfo;
        end
    end
end
