classdef tStructuredContentAlways < prodserver.mcp.test.base.MCPHandlerBase
% A tool that publishes an output schema returns structured content from
% every successful call, even with nothing inline to return: MCP requires
% it, and clients that check reject the result without it. The two ways to
% have nothing inline: no outputs at all, or only by-reference outputs
% called without their URLs.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function buildTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.fcnNames = ["toyNoOutputs", "toyByReferenceOutput"];
            test.toolNames = test.fcnNames;
            % Definitions and wrappers only, into the folder the handler
            % reads them from.
            prodserver.mcp.build(test.fcnNames, folder=test.tempFolder, ...
                stop="Definition");
        end
    end

    methods (Test)

        function noOutputs(test)
            response = test.callTool("toyNoOutputs", "x", 3);
            test.verifyEmptyStructuredContent(response);
        end

        function byReferenceOutputOmitted(test)
            % The output's URL is optional: without it, nothing is written
            % and nothing is returned inline.
            response = test.callTool("toyByReferenceOutput", "x", 3);
            test.verifyEmptyStructuredContent(response);
        end

    end

    methods (Access = private)

        function response = callTool(test, tool, varargin)
            request = createRequest(test, tool, test.server, varargin{:});
            response = decodeResponse(test, request, ...
                prodserver.mcp.internal.mcpHandler(request));
        end

        function verifyEmptyStructuredContent(test, response)
            import prodserver.mcp.internal.hasField
            test.assertFalse(hasField(response, "result.isError"), ...
                "The call should succeed.");
            present = hasField(response, "result.structuredContent");
            test.verifyTrue(present, ...
                "A tool with an output schema must return structured content.");
            if present
                test.verifyEmpty(fieldnames(response.result.structuredContent), ...
                    "There is nothing inline to return.");
            end
        end

    end

end
