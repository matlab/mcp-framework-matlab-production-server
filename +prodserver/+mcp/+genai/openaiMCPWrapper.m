function wrapper = openaiMCPWrapper(fcn,genAI,folder,timeout,retry)
% openaiMCPWrapper Use OpenAI to generate a wrapper function for fcn.

% Copyright 2025, The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    % Verify that the required environment variable exists.
    if isKey(MCPConstants.GenAIEnvVar,genAI) && ...
            isempty(getenv(MCPConstants.GenAIEnvVar(genAI)))
        error("prodserver:mcp:MissingGenAI_API_KEY", ...
            "Missing API key for %s. Set environment variable %s.", ...
            string(genAI),MCPConstants.GenAIEnvVar(genAI));
    end

    prompt_file = fullfile(fileparts(mfilename("fullpath")),...
        "WrapperFunction.prompt");
    prompt = string(fileread(prompt_file));
    fcn_data = string(fileread(fcn));
    prompt = prompt + fcn_data;
    systemPrompt = "You are a helpful assistant.";

    text = "";
    N = 0;
    while strlength(text) == 0 && N < retry
        try
            chat = openAIChat(systemPrompt, ModelName="gpt-4o",TimeOut=timeout);
            [text, response] = generate(chat, prompt);
            % TODO: check for errors
        catch ex
            if strcmpi(ex.identifier,"MATLAB:webservices:timeout") == false
                rethrow(ex)
            end
        end
        N = N + 1;
    end

    % Make sure we got some code
    if isempty(text) || strlength(text) == 0
        error("prodserver:mcp:GenAINoResponse", ...
  "%s failed to respond after %d tries of %s seconds each. Increase " + ...
  "timeout or number of retries.", string(genAI), retry+1, timeout);
    end

    if contains(text,"```matlab") == false
        error("prodserver:mcp:GenAINoWrapper", ...
            "Response from %s contained no MATLAB code.", string(genAI));
    end

    % Write the code into the wrapper file.
    code = extractBetween(text,"```matlab","```");

    [~,f,e] = fileparts(fcn);
    wrapper = fullfile(folder,...
        string(f)+MCPConstants.WrapperFileSuffix+e);
    writelines(code,wrapper);
end