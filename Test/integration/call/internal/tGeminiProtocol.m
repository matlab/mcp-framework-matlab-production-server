classdef tGeminiProtocol < tLLMProtocol
%tGeminiProtocol Verify Gemini connects to and calls a deployed MCP tool.

% Copyright 2026 The MathWorks, Inc.

    methods (Access = protected)

        function agent = agentFor(~, server, endpoint)
            agent = prodserver.mcp.test.mixin.GeminiAgent(server, endpoint);
        end

    end

end
