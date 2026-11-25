classdef tMetricsFault < prodserver.mcp.test.base.MCPHandlerBase
% A metric write that fails loses one count, not the request. On a server
% whose writes failed now and then ("Error writing to output stream.
% iostream stream error"), every failure failed the MCP request it counted
% with -32603, whatever its method. A stand-in for MPS's incrementCounter
% that always fails reproduces that here.
%
% The stand-in is written to a temporary folder, not kept in the
% repository: CI puts every folder of the repository on the path, and a
% stand-in there shadowed the real incrementCounter for every other test,
% so no metric was ever written.

% Copyright 2026 The MathWorks, Inc.

    properties
        Captured    % LogCapture
        FaultFolder % The folder of the failing stand-in
    end

    methods (TestClassSetup)
        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));
            test.fcnNames = "toyScalarTwo";
            test.toolNames = test.fcnNames;
            defineTools(test, test.fcnNames, test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.JSON);
        end

        function writeFailingStandIn(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            test.FaultFolder = test.applyFixture(TemporaryFolderFixture).Folder;
            package = fullfile(test.FaultFolder, "+prodserver", "+metrics");
            mkdir(package);
            writelines([
                "function incrementCounter(name, value) %#ok<INUSD>"
                "% A stand-in for incrementCounter that fails, as it did on a server"
                "% whose metric writes failed."
                "    error(""prodserver:mcp:test:MetricsFault"", ..."
                "        ""Error writing to output stream. iostream stream error"");"
                "end"], fullfile(package, "incrementCounter.m"));
        end
    end

    methods (TestMethodSetup)
        function failMetricWrites(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(test.FaultFolder));
            % A fresh Log for each test: the warnings are throttled per
            % metric, and the throttle lives in the Log.
            prodserver.mcp.logging.Log.instance(action="clear");
            test.addTeardown(@() prodserver.mcp.logging.Log.instance(action="clear"));
            test.Captured = test.applyFixture(prodserver.mcp.test.mixin.LogCapture());
        end
    end

    methods

        function decoded = post(test, method, params)
            import prodserver.mcp.MCPConstants
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];
            body = struct('jsonrpc', "2.0", 'id', 1, 'method', method);
            if nargin > 2
                body.params = params;
            end
            [req, body] = test.applyProtocol(req, jsonencode(body));
            req.Method = "POST";
            req.Path = "/toyScalarTwo/mcp";
            req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body, "UTF-8");
            lastwarn("");
            response = test.handle(req);
            test.verifyEqual(response.HttpCode, 200, method);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.verifyFalse(isfield(decoded, 'error'), method + ...
                " must not fail because a metric couldn't be written");
            test.verifyEqual(lastwarn(), '', method + ...
                ": the elapsed-time write must not warn from onCleanup");
        end

        function verifyLostCounts(test, metrics)
            lost = test.Captured.Lines(contains(test.Captured.Lines, ...
                "prodserver:mcp:MetricWriteFailed"));
            for m = metrics
                test.verifyEqual(nnz(contains(lost, "from the metric " + m + ":")), 1, ...
                    "One warning for " + m + newline + strjoin(lost, newline));
            end
            test.verifyTrue(all(contains(lost, "iostream stream error")), ...
                strjoin(lost, newline));
        end
    end

    methods (Test)

        function initializeSucceeds(test)
            test.assumeEqual(test.protocol, "2025-06-18", ...
                "2026-07-28 has no initialize");
            decoded = test.post("initialize", struct('protocolVersion', ...
                "2025-06-18", 'capabilities', struct(), 'clientInfo', ...
                struct('name', "t", 'version', "1")));
            test.verifyTrue(isfield(decoded.result, 'protocolVersion'));
        end

        function toolsListSucceeds(test)
            decoded = test.post("tools/list");
            test.verifyEqual(string(decoded.result.tools(1).name), "toyScalarTwo");
            test.verifyLostCounts(["MCP_Framework_Request" ...
                "MCP_toyScalarTwo_Request" "MCP_toyScalarTwo_ElapsedTime"]);
        end

        function toolsCallSucceeds(test)
            decoded = test.post("tools/call", struct('name', "toyScalarTwo", ...
                'arguments', struct('s', "abc", 'n', 1)));
            test.assertTrue(isfield(decoded.result, 'structuredContent'));
            test.verifyTrue(all(isfield(decoded.result.structuredContent, ...
                {'cs', 'd'})));
            test.verifyLostCounts(["MCP_Framework_Request" ...
                "MCP_toyScalarTwo_Request" "MCP_toyScalarTwo_Call"]);
        end

        function steadyFailureLogsOncePerMetric(test)
            % A server whose writes always fail would log every request.
            for k = 1:3
                test.post("tools/list");
            end
            test.verifyLostCounts(["MCP_Framework_Request" ...
                "MCP_toyScalarTwo_Request" "MCP_toyScalarTwo_ElapsedTime"]);
        end

        function tryIncrementCounterNeverRaises(test)
            prodserver.mcp.internal.tryIncrementCounter("Some_Metric", 2);
            lost = test.Captured.Lines(end);
            test.verifySubstring(lost, "prodserver:mcp:MetricWriteFailed");
            test.verifySubstring(lost, "Lost 2 from the metric Some_Metric");
        end

    end
end
