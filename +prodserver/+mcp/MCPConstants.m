classdef MCPConstants
    
% Copyright 2025, The MathWorks, Inc.

    properties (Constant)
        SessionId = 'Mcp-Session-Id'
        ProtocolVersion = 'MCP-Protocol-Version';
        DefinitionFile = "McpServices.mat";
        DefinitionVariable = "mcpToolDefinition";
        NoWrapper = "None";
        ContentType = 'Content-Type';
        ContentLength = 'Content-Length';
        Host = 'Host';
        SSE = "/sse";
        MCP = "/mcp";
        Signature = "/signature";
        WrapperFileSuffix = "MCP";
        ExternalParamSuffix = "URL";
        jrpcVersion = "2.0"
        protocolVersion = "2025-06-18";

        DefaultArgType = "double";  

        IndirectionMsg = "Refer to structuredContent for tool results.";

        % Call and response
        Ping = "ping";
        Pong = "pong";

        % Map GenerativeAI enum values to environment variables
        GenAIEnvVar = dictionary( ...
            prodserver.mcp.GenerativeAI.OpenAI, "OPENAI_API_KEY", ...
            prodserver.mcp.GenerativeAI.Gemini, "GEMINI_API_KEY", ...
            prodserver.mcp.GenerativeAI.Anthropic, "ANTHROPIC_API_KEY", ...
            prodserver.mcp.GenerativeAI.Ollama, "", ...
            prodserver.mcp.GenerativeAI.Internal, "", ...
            prodserver.mcp.GenerativeAI.None, "");
    end
end
