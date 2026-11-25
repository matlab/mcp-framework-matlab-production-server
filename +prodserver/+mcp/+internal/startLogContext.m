function startLogContext(log, request, jrpc)
%startLogContext Start the log's context for a decoded message.
%
%   startLogContext(LOG, REQUEST, JRPC) calls LOG.beginRequest(JRPC), for
%   the message's id, then sets its trace as a handle the logger calls only
%   when it writes a line (FND-16): a request that logs nothing never
%   parses its trace context. _meta's context wins over the header's
%   (FND-36). mcpHandler calls it once the body decodes, on POST and
%   DELETE; it is a function of its own so the performance test times what
%   each request pays (tArchiveCachePerformance).
%
%   The handle captures only the four bounded values it parses, never the
%   headers, which hold credentials, nor _meta, whose size the client
%   chooses: the logger keeps it until the request ends (FA-24).
%
%   See also prodserver.mcp.logging.Log, prodserver.mcp.internal.TraceContext

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      command (the log's context only; no I/O)
%   Requires:  log is a prodserver.mcp.logging.Log  (internal)
%   Ensures:   the log's id is JRPC's; its trace is a handle that holds four strings
%   Raises:    none

    log.beginRequest(jrpc);
    [metaParent, metaState] = prodserver.mcp.internal.TraceContext.metaFields(jrpc);
    [headerParent, headerState] = prodserver.mcp.internal.TraceContext.headerFields(request);
    log.setContext(trace=@() prodserver.mcp.internal.TraceContext.select( ...
        prodserver.mcp.internal.TraceContext(metaParent, metaState), ...
        prodserver.mcp.internal.TraceContext(headerParent, headerState)));
end
