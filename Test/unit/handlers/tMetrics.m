classdef tMetrics < prodserver.mcp.test.base.MCPHandlerBase
% Test that mcpHandler emits the expected metrics via
% prodserver.metrics.incrementCounter. In a MATLAB desktop session (not
% deployed to MPS), incrementCounter prints to the command window rather
% than updating a persistent counter store. We capture that output with
% evalc and parse it to verify metric names and per-call increment values.
%
% LIMITATION: These tests verify that the correct metric names are emitted
% with the correct per-call increment (always 1), but cannot verify the
% accumulated total across multiple calls. Accumulated-value assertions
% require a live MPS instance and are covered by the integration test
% Test/integration/call/tMetrics.m.

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    methods (TestClassSetup)

        function prepareTools(test, encoding)
            import matlab.unittest.fixtures.PathFixture

            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples());

            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));

            test.fcnNames = ["primeSequence","read_mcp_resource"];
            test.toolNames = ["primeSequence","read_mcp_resource"];

            defineTools(test, test.fcnNames, test.toolNames,encoding=encoding);
        end
    end

    methods (Access = private)

        function metrics = parseMetricOutput(~, output)
        % Parse [metric:counter] lines from evalc output.
        %
        % Each line has the format:
        %   [metric:counter] <version>|<name> <value>
        %
        % Returns a struct array with fields 'name' (string) and
        % 'value' (double).
            lines = splitlines(string(output));
            lines = lines(startsWith(lines, "[metric:counter]"));
            metrics = struct('name', {}, 'value', {});
            for k = 1:numel(lines)
                tokens = split(erase(lines(k), "[metric:counter] "));
                versionAndName = tokens(1);
                parts = split(versionAndName, "|");
                metrics(k).name = parts(end);
                metrics(k).value = double(tokens(2));
            end
        end

        function reqT = buildJsonRpcRequest(test, method, params)
        % Build an MCP JSON-RPC request struct for the given method.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            req.Headers = [req.Headers; ...
                {MCPConstants.SessionId, matlab.lang.internal.uuid}];

            body = jsonencode(struct( ...
                'jsonrpc', "2.0", ...
                'id', 1, ...
                'method', method, ...
                'params', params));

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body, "UTF-8");
        end

    end

    methods (Test)

        function toolsListEmitsThreeMetrics(test)
        % tools/list should emit exactly three counters: the framework
        % request metric, the server request metric and the elapsed time.
            import prodserver.mcp.MCPConstants

            reqT = buildJsonRpcRequest(test, "tools/list", ...
                struct('cursor', ""));

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            metrics = parseMetricOutput(test, output);

            test.verifyEqual(numel(metrics), 3, ...
                "tools/list should emit exactly 3 metrics");

            names = [metrics.name];
            test.verifyTrue(ismember(MCPConstants.MCPRequestMetric, names), ...
                "Missing framework request metric");
            test.verifyTrue(ismember( ...
                MCPConstants.MCPMetricPrefix + "prime" + ...
                MCPConstants.MCPMetricSuffix, names), ...
                "Missing server request metric");
        end

        function toolsCallEmitsFourMetrics(test)
        % tools/call should emit three counters: framework request,
        % server request, per-tool call metric and the elapsed time.
            import prodserver.mcp.MCPConstants

            reqT = buildJsonRpcRequest(test, "tools/call", ...
                struct('name', "primeSequence", ...
                       'arguments', struct('n', 5, 'type', "Mersenne")));

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            metrics = parseMetricOutput(test, output);

            test.verifyEqual(numel(metrics), 4, ...
                "tools/call should emit exactly 4 metrics");

            names = [metrics.name];
            test.verifyTrue(ismember(MCPConstants.MCPRequestMetric, names), ...
                "Missing framework request metric");
            test.verifyTrue(ismember( ...
                MCPConstants.MCPMetricPrefix + "prime" + ...
                MCPConstants.MCPMetricSuffix, names), ...
                "Missing server request metric");
            test.verifyTrue(ismember( ...
                MCPConstants.MCPMetricPrefix + "primeSequence" + ...
                MCPConstants.MCPToolCallSuffix, names), ...
                "Missing tool call metric");
        end

        function serverMetricMatchesPathSegment(test)
        % The server metric name is derived from the first path segment
        % of the request URL.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];
            req.Headers = [req.Headers; ...
                {MCPConstants.SessionId, matlab.lang.internal.uuid}];

            body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}';
            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/MyCustomArchive/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body, "UTF-8");

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            metrics = parseMetricOutput(test, output);

            names = [metrics.name];
            expected = MCPConstants.MCPMetricPrefix + ...
                "MyCustomArchive" + MCPConstants.MCPMetricSuffix;
            test.verifyTrue(ismember(expected, names), ...
                "Server metric should use path segment as name");
        end

        function toolCallMetricMatchesToolName(test)
        % The tool-call metric should use the tool's name, not the
        % function name or archive name.
            import prodserver.mcp.MCPConstants

            reqT = buildJsonRpcRequest(test, "tools/call", ...
                struct('name', "primeSequence", ...
                       'arguments', struct('n', 3, 'type', "Mersenne")));

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            metrics = parseMetricOutput(test, output);

            names = [metrics.name];
            expected = MCPConstants.MCPMetricPrefix + ...
                "primeSequence" + MCPConstants.MCPToolCallSuffix;
            test.verifyTrue(ismember(expected, names), ...
                "Tool call metric should use tool name");
        end

        function mostIncrementsAreOne(test)
        % The framework always passes 1 to incrementCounter. Verify
        % that every emitted counter in a single request has value 1.
        % Except for elapsed time, which will never be exactly one second.
            import prodserver.mcp.MCPConstants

            reqT = buildJsonRpcRequest(test, "tools/call", ...
                struct('name', "primeSequence", ...
                       'arguments', struct('n', 7, 'type', "Mersenne")));

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            metrics = parseMetricOutput(test, output);

            for k = 1:numel(metrics)
                if contains(metrics(k).name,"Elapsed") == false
                    test.verifyEqual(metrics(k).value, 1, ...
                        "Metric " + metrics(k).name + ...
                        " should increment by 1");
                end
            end
        end

    end
end
