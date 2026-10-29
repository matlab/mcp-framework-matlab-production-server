function [httpCode, httpMsg, msgHeaders] = methodNotAllowed(allow)
%methodNotAllowed Status, reason phrase and headers of a 405 response.
%   RFC 9110 §15.5.6: a 405 MUST carry an Allow header listing the methods
%   the target resource supports. Every 405 the MCP endpoint sends is built
%   here, so none can leave it out (G11).
%
%   ALLOW defaults to the methods the endpoint as a whole accepts, which is
%   all mcpHandler can say: its 405s fire before, or because of, a failed
%   protocol attribution. An adapter that knows its revision passes its own.

% Copyright 2026 The MathWorks, Inc.

    arguments
        allow char = prodserver.mcp.MCPConstants.AllowedMethods
    end

    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(405);
    msgHeaders = {'Allow', allow};
end
