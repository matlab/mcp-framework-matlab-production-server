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

            body = jsonencode(struct( ...
                'jsonrpc', "2.0", ...
                'id', 1, ...
                'method', method, ...
                'params', params));
            [req, body] = test.applyProtocol(req, body);

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

        function toolsCallEmitsFiveMetrics(test)
        % tools/call should emit three counters: framework request,
        % server request, per-tool call metric and the elapsed time.
            import prodserver.mcp.MCPConstants

            reqT = buildJsonRpcRequest(test, "tools/call", ...
                struct('name', "primeSequence", ...
                       'arguments', struct('n', 5, 'type', "Mersenne")));

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            metrics = parseMetricOutput(test, output);

            test.verifyEqual(numel(metrics), 5, ...
                "tools/call should emit exactly 5 metrics");

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

            test.verifyTrue(ismember( ...
                MCPConstants.MCPMetricPrefix + "primeSequence" + ...
                MCPConstants.MCPToolCallSuffix + "_" + ...
                replace(test.protocol,"-","_"), names), ...
                "Missing protocol version of tool call metric");

            % "Mersenne" isn't a sequence primeSequence knows, so the tool
            % ran and failed: a call, not a rejection.
            test.verifyFalse(any(contains(names, ...
                MCPConstants.MCPToolRejectedSuffix)), ...
                "A tool that ran is not a rejected call");
        end

        function rejectedCallIsCountedAsRejection(test)
        % A call the server refuses before invoking the tool -- a missing,
        % unknown or invalid argument -- is counted in MCP_<tool>_Rejected,
        % not MCP_<tool>_Call, under either revision's way of reporting it.
            import prodserver.mcp.MCPConstants

            stem = MCPConstants.MCPMetricPrefix + "primeSequence";
            rev = "_" + replace(test.protocol, "-", "_");
            cases = {
                struct('type', "Eisenstein"),                   "missing n"
                struct('n', 5, 'type', "Eisenstein", 'zzz', 1), "unknown zzz"
                struct('n', "3", 'type', "Eisenstein"),          "string for n"
                };
            for k = 1:size(cases, 1)
                reqT = buildJsonRpcRequest(test, "tools/call", ...
                    struct('name', "primeSequence", 'arguments', cases{k,1}));
                output = evalc( ...
                    "response = prodserver.mcp.internal.mcpHandler(reqT);");
                metrics = parseMetricOutput(test, output);
                names = [metrics.name];

                test.verifyEqual(numel(metrics), 5, cases{k,2} + ...
                    ": three request metrics and two rejection counters");
                test.verifyTrue(ismember(stem + ...
                    MCPConstants.MCPToolRejectedSuffix, names), cases{k,2});
                test.verifyTrue(ismember(stem + ...
                    MCPConstants.MCPToolRejectedSuffix + rev, names), ...
                    cases{k,2});
                test.verifyFalse(any(contains(names, ...
                    MCPConstants.MCPToolCallSuffix)), cases{k,2} + ...
                    ": the tool was not invoked, so this is not a call");
            end
        end

        function protocolMetricFollowsServingRevision(test)
        % The per-revision tool-call metric must name the revision that
        % SERVED the call, which is not always the one the request declared.
        % An alias is exactly where the two part company: a request declaring
        % 2024-11-05 is routed to the 2025-06-18 adapter, so that is the
        % bucket the call belongs in. Deriving the bucket from the body
        % instead files it under a version supportedVersions() excludes, and
        % no amount of staring at the metric store reveals why.
        %
        % This case cannot be reached through applyProtocol, which always
        % declares one of the registered versions, so the request is built
        % here by hand.
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            alias = "2024-11-05";
            registry = prodserver.mcp.protocol.ProtocolRegistry.instance();
            serving = registry.lookup(alias).Version;
            test.assumeNotEqual(serving, alias, ...
                "This test needs an alias, i.e. a routable version that is " + ...
                "not itself registered as an adapter.");

            body = struct('jsonrpc', "2.0", 'id', 1, 'method', "tools/call");
            body.params.name = "primeSequence";
            body.params.arguments = struct('n', 5, 'type', "Mersenne");
            body.params.(MCPConstants.MetaField).( ...
                C.MetaProtocolVersion_Field) = alias;
            body = jsonencode(body);

            reqT = test.request;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentType, 'application/json'}; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body, "UTF-8");

            output = evalc( ...
                "response = prodserver.mcp.internal.mcpHandler(reqT);");
            test.assertEqual(response.HttpCode, 200, ...
                "The aliased request must be served, not rejected");
            names = [parseMetricOutput(test, output).name];

            stem = MCPConstants.MCPMetricPrefix + "primeSequence" + ...
                MCPConstants.MCPToolCallSuffix + "_";
            test.verifyTrue(ismember(stem + replace(serving, "-", "_"), names), ...
                "Tool call should be filed under the serving revision " + serving);
            test.verifyFalse(ismember(stem + replace(alias, "-", "_"), names), ...
                "Tool call must not be filed under the alias " + alias + ...
                ", which is not a supported version");
        end

        function serverMetricMatchesPathSegment(test)
        % The server metric name is derived from the first path segment
        % of the request URL.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}];

            body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}';
            [req, body] = test.applyProtocol(req, body);
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
