classdef GenerativeAI

% Copyright 2025, The MathWorks, Inc.

    enumeration
        OpenAI      % OpenAI
        Gemini      % Google's Gemini
        Anthropic   % Claude
        Ollama      % Meta
        Internal    % Determined by implementation
        None        % No GenAI interface known or available.
        Disable     % Do not use AI to generate MCP tool.
    end
end
