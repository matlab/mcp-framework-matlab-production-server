function data = unsupportedVersionData(requested)
%unsupportedVersionData The UnsupportedProtocolVersionError payload.
%   DATA = unsupportedVersionData(REQUESTED) returns the `error.data` for a
%   request rejected because it stated version REQUESTED: every version this
%   server supports, and the one the caller asked for.
%
%   2026-07-28's schema.ts declares `supported` and `requested` without `?`,
%   so neither is optional there: a client that guessed the version wrong
%   cannot recover without being told what it asked for and what it could
%   have asked for. 2025-06-18 defines no payload and borrows this one (see
%   v20250618.Adapter.preDetectionError), which is why the builder lives
%   here rather than in either revision.
%
%   The caller supplies REQUESTED because only the caller knows where its
%   revision states a version. Adapter.requestedVersion is the usual source.

% Copyright 2026 The MathWorks, Inc.

    arguments
        requested (1,1) string = ""
    end

    registry = prodserver.mcp.protocol.ProtocolRegistry.instance();
    data.supported = registry.supportedVersions();
    data.requested = requested;
end
