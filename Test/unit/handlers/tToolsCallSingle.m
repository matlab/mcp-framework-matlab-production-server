classdef tToolsCallSingle < prodserver.mcp.test.base.MCPHandlerBase
% A tool declared with single arguments builds under both encodings and,
% under Invertible, takes and returns singles end to end. (Declaring single
% used to fail the build: the declared path's type mapping lacked it.)

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));
            test.fcnNames = "toySingleHalf";
            test.toolNames = test.fcnNames;
            defineTools(test,test.fcnNames,test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.Invertible);
        end
    end

    properties (TestParameter)
        encoding = {"JSON", "Invertible"}
    end

    methods (Test)

        function declaredSingleSchemas(test, encoding)
            d = prodserver.mcp.internal.mcpDefinition("toySingleHalf", ...
                "toySingleHalf", encoding=encoding);
            in = d.tools.inputSchema.properties;
            out = d.tools.outputSchema.properties;
            if encoding == "Invertible"
                w = @prodserver.mcp.test.wrapperOf;
                test.verifyTrue(ismember("single", string(w(in.xs).properties.type.enum)));
                test.verifyEqual(string(w(out.v).properties.type.enum), "single");
                [~, in.x] = w(in.x);  [~, in.xs] = w(in.xs);
            end
            test.verifyEqual(in.x.type, "number");
            test.verifyEqual(in.xs.type, "array");
            test.verifyEqual(in.xs.items.type, "number");
        end

        function singlesEndToEnd(test)
            % A wrapped single array in; singles out, tagged single.
            import prodserver.mcp.MCPConstants
            args = struct('x', 3, 'xs', struct('type', "single", ...
                'size', [1 2], 'data', [5 7]));
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                char(prodserver.mcp.internal.Constants.MIMETypeJSON)}];
            body = jsonencode(struct('jsonrpc', "2.0", 'id', 1, ...
                'method', "tools/call", 'params', struct( ...
                'name', "toySingleHalf", 'arguments', args)));
            [req, body] = test.applyProtocol(req, body);
            req.Method = "POST";
            req.Path = "/toySingleHalf/mcp";
            req.Body = unicode2native(body, "UTF-8");
            req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(req.Body)}];
            decoded = prodserver.mcp.internal.decodeBody(test.handle(req));

            test.assertTrue(isfield(decoded, 'result') && ...
                isfield(decoded.result, 'structuredContent'), "A result");
            sc = decoded.result.structuredContent;
            test.verifyEqual(sc.v.type, 'single');
            v = prodserver.mcp.jsonrpc.mcpWireDecodeValue(sc.v);
            test.verifyEqual(v, single([2.5 3.5]));
            r = prodserver.mcp.jsonrpc.mcpWireDecodeValue(sc.r);
            test.verifyEqual(double(r), 1.5);
        end

    end
end
