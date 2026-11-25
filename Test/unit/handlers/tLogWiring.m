classdef tLogWiring < prodserver.mcp.test.base.MCPHandlerBase
% The logger on main's request path: mcpHandler starts each request's
% context and ends it, tools/call names the tool, the trace comes from
% _meta or the header, and notifications/cancelled logs RequestCancelled.
% The tool toyLogProbe writes one line during its request, so a test reads
% the request's context from that line.

% Copyright 2026 The MathWorks, Inc.

    properties
        Captured    % LogCapture
    end

    properties (Constant)
        TP = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        OtherTP = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    end

    methods (TestClassSetup)
        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(fullfile(prodserver.mcp.internal.packageFolder(), ...
                "server", "tools")));
            test.fcnNames = "toyLogProbe";
            test.toolNames = test.fcnNames;
            defineTools(test, test.fcnNames, test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.Invertible);
        end
    end

    methods (TestMethodSetup)
        function captureLog(test)
            test.Captured = test.applyFixture(prodserver.mcp.test.mixin.LogCapture());
        end
    end

    methods (Test)

        function toolsCallCarriesItsIdAndTool(test)
            probe(test, 7);
            line = probeLine(test);
            test.verifySubstring(line, " id=7 ");
            test.verifySubstring(line, " tool=toyLogProbe ");
            test.verifyFalse(contains(line, "trace="), "the request sent no trace");
        end

        function theHeaderTraceIsUsedWhenMetaHasNone(test)
            % Claude Code sends the trace as a header only (FND-16, FND-36).
            probe(test, 9, header=test.TP);
            test.verifySubstring(probeLine(test), " trace=" + test.TP + " ");
        end

        function theMetaTraceIsUsed(test)
            probe(test, 10, meta=test.TP);
            test.verifySubstring(probeLine(test), " trace=" + test.TP + " ");
        end

        function theMetaTraceWinsOverTheHeader(test)
            % FND-36: _meta's context is the parent; the header's is a link.
            probe(test, 11, meta=test.TP, header=test.OtherTP);
            line = probeLine(test);
            test.verifySubstring(line, " trace=" + test.TP + " ");
            test.verifyFalse(contains(line, test.OtherTP), line);
        end

        function aRequestLeavesNoContextBehind(test)
            % A line written after the request, as an admin route's would
            % be, carries none of the request's fields.
            probe(test, 12, header=test.TP);
            lineAfter(test);
            test.verifyFalse(contains(test.Captured.Lines(end), ["id=", "trace=", "tool="]), ...
                test.Captured.Lines(end));
        end

        function aRequestThatFailsLeavesNoContextBehind(test)
            probe(test, 13, header=test.TP);
            post(test, "{not json", {'traceparent', char(test.OtherTP)});
            lineAfter(test);
            test.verifyFalse(contains(test.Captured.Lines(end), ["id=", "trace=", "tool="]), ...
                test.Captured.Lines(end));
        end

        function aDeleteWithATraceLeavesNoContextBehind(test)
            import prodserver.mcp.MCPConstants
            req = test.request;
            req.Method = "DELETE";
            req.Path = "/toyLogProbe/mcp";
            req.Headers = [req.Headers; {'traceparent', char(test.TP)}; ...
                {MCPConstants.ContentLength, '0'}];
            response = prodserver.mcp.internal.mcpHandler(req);
            test.verifyEqual(response.HttpCode, 405, "a DELETE no protocol claims");
            lineAfter(test);
            test.verifyFalse(contains(test.Captured.Lines(end), ["id=", "trace="]), ...
                test.Captured.Lines(end));
        end

        function aRequestThatLogsNothingNeverParsesItsTrace(test)
            % The trace is a handle the logger calls only when it writes a
            % line (FND-16), so a request that writes none never parses it:
            % neither the constructor nor select runs. Reading the text out
            % of the request (metaFields, headerFields) parses nothing.
            profile clear
            profile on
            post(test, struct("jsonrpc", "2.0", "id", 14, "method", "tools/list"), ...
                {'traceparent', char(test.TP)});
            profile off
            info = profile("info");
            profile clear
            test.verifyEmpty(test.Captured.Lines, "the request itself wrote no line");
            called = string({info.FunctionTable.FunctionName});
            parsed = called(endsWith(called, ["TraceContext.TraceContext", "TraceContext.select"]));
            test.verifyEmpty(parsed, strjoin(parsed, newline));
        end

        function cancellationIsLogged(test)
            response = post(test, struct("jsonrpc", "2.0", "method", "notifications/cancelled", ...
                "params", struct("requestId", 5, "reason", "user aborted")));
            test.verifyEqual(response.HttpCode, 202);
            test.verifyEmpty(response.Body);
            hit = test.Captured.Lines(contains(test.Captured.Lines, "prodserver:mcp:RequestCancelled"));
            test.verifyNumElements(hit, 1);
            test.verifySubstring(hit, "[mcp:information] prodserver:mcp:RequestCancelled");
            test.verifySubstring(hit, "Request `5` cancelled: `user aborted`");
        end
    end

    methods (Access = private)
        function response = probe(test, id, opts)
        % A tools/call of toyLogProbe, with a trace in _meta, in the
        % traceparent header, or in both.
            arguments
                test
                id
                opts.meta (1,1) string = missing
                opts.header (1,1) string = missing
            end
            message = struct("jsonrpc", "2.0", "id", id, "method", "tools/call", ...
                "params", struct("name", "toyLogProbe", "arguments", struct("x", 1)));
            if ~ismissing(opts.meta)
                message.params.(prodserver.mcp.MCPConstants.MetaField) = ...
                    struct("traceparent", opts.meta);
            end
            headers = cell(0, 2);
            if ~ismissing(opts.header)
                headers = {'traceparent', char(opts.header)};
            end
            response = post(test, message, headers);
            test.verifyEqual(response.HttpCode, 200, native2unicode(response.Body, "UTF-8"));
        end

        function line = probeLine(test)
        % The one line toyLogProbe wrote.
            line = test.Captured.Lines(endsWith(test.Captured.Lines, " probe"));
            test.fatalAssertNumElements(line, 1, join(test.Captured.Lines, newline));
        end

        function response = post(test, message, extraHeaders)
            arguments
                test
                message
                extraHeaders cell = cell(0, 2)
            end
            import prodserver.mcp.MCPConstants
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                char(prodserver.mcp.internal.Constants.MIMETypeJSON)}; extraHeaders];
            body = message;
            if ~ischar(body) && ~isstring(body)
                body = jsonencode(message);
                [req, body] = test.applyProtocol(req, body);
            end
            req.Method = "POST";
            req.Path = "/toyLogProbe/mcp";
            req.Body = unicode2native(char(body), "UTF-8");
            req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(req.Body)}];
            response = prodserver.mcp.internal.mcpHandler(req);
        end

        function lineAfter(~)
            % A line written now carries whatever context the last request left.
            prodserver.mcp.logging.Log.instance().log("Information", ...
                "prodserver:mcp:TracingEnabled", "after");
        end
    end
end
