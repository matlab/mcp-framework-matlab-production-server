classdef tDeployedSignature < prodserver.mcp.test.base.MCPHandlerBase
% tools/call against a definition shaped the way a deployed archive's is.
%
% build(..., example=) generates the definition by observing example calls
% (prodserver.mcp.schema, through SchemaObserver). For a tool that takes no
% inputs that signature has no 'input' member at all, and every call to the
% deployed tool failed with -32603/500 (ND12). Every other suite builds its
% definition with defineForMCP, which always writes an empty 'input', so
% none of them could see it.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Tool = "toyZeroInputs";
    end

    methods (TestClassSetup)

        function prepareTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            % The path build(..., example=) takes: observe, then hand the
            % observed definition to defineForMCP as a complete one.
            observed = prodserver.mcp.schema(test.Tool, ...
                {@() toyZeroInputs()});
            definition = prodserver.mcp.internal.defineForMCP(test.Tool, ...
                test.Tool, definition=num2cell(observed), ...
                encoding=prodserver.mcp.WireEncoding.JSON);
            defineTools(test, test.Tool, test.Tool, definition=definition);
            test.addTeardown(@() ...
                prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function zeroInputToolSucceeds(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Precondition: the signature really is the deployed shape.
            % Should observation ever start writing an empty 'input', this
            % test would quietly stop covering ND12.
            svc = prodserver.mcp.handler.toolServices;
            sig = svc.(MCPConstants.DefinitionVariable).signatures;
            test.assertTrue(isfield(sig, test.Tool));
            test.assertFalse(isfield(sig.(test.Tool), "input"), ...
                "Precondition: an observed zero-input signature has no 'input'");

            reqT = createRequest(test, test.Tool, test.server);
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 200, ...
                native2unicode(response.Body, "UTF-8"));
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded, "result.structuredContent"), ...
                native2unicode(response.Body, "UTF-8"));
            test.verifyFalse(hasField(decoded, "result.isError"));
            test.verifyEqual(sort(string(fieldnames( ...
                decoded.result.structuredContent)))', ...
                sort(["n","extent","hero","area","cover"]));
        end
    end
end
