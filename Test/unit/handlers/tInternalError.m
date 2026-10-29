classdef tInternalError < prodserver.mcp.test.base.MCPHandlerBase
% End-to-end pin of D42's -32603 -> HTTP 500, for every revision.
%
% Every other suite asserts that some fault does NOT become -32603/500. None
% drove a genuine server fault through the whole of mcpHandler and checked
% the status that comes out, so a mapper change from 500 to 200 would have
% passed the entire unit suite.
%
% The fault is a definition file that lists a tool in 'tools' but has no
% 'signatures' entry for it: an inconsistency only a broken build can
% produce, which no request can correct, and which tools/call can therefore
% only report as an internal error.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        InternalError = -32603;
        Tool = "toyScalarTwo";
    end

    methods (TestClassSetup)

        function prepareTools(test)
            import prodserver.mcp.MCPConstants

            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            defineTools(test, test.Tool, test.Tool, ...
                encoding=prodserver.mcp.WireEncoding.JSON);

            % Break the definition: keep the tool, drop its signature.
            d = load(test.definitionFile);
            def = d.(MCPConstants.DefinitionVariable);
            def.signatures = rmfield(def.signatures, test.Tool);
            d.(MCPConstants.DefinitionVariable) = def;
            save(test.definitionFile, "-struct", "d");

            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() ...
                prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function brokenDefinitionIs500(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            % Precondition: the fault is the one this test claims. Without
            % it, a definition that lost the tool altogether would produce
            % ToolUnavailable/-32602 and the test would be pinning the
            % wrong path.
            svc = prodserver.mcp.handler.toolServices;
            def = svc.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t) string(t.name), def.tools);
            test.assertTrue(any(names == test.Tool), ...
                "Precondition: the tool must be listed in 'tools'");
            test.assertFalse(isfield(def.signatures, test.Tool), ...
                "Precondition: the tool must have no 'signatures' entry");

            reqT = createRequest(test, test.Tool, test.server, ...
                s="hello world", n=2);
            response = test.handle(reqT);

            test.verifyEqual(response.HttpCode, 500, ...
                native2unicode(response.Body, "UTF-8"));
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(hasField(decoded, 'error.code'), ...
                native2unicode(response.Body, "UTF-8"));
            test.verifyEqual(decoded.error.code, test.InternalError);
            test.verifyEqual(decoded.id, 1);
        end
    end
end
