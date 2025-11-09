function response = taskOpenAI(prompt,mcpTools)
% taskOpenAI Assign OpenAI LLMs the task given by the input prompt. 

% Copyright 2025, The MathWorks, Inc.

    % Convert MCP tool format to OpenAI function objects.
    tools = mcpToOpenAI(mcpTools);

    % Add a terminal tool, which the AI agent must call to indicate
    % processing is complete.
    finalAnswer = openAIFunction("finalAnswer", ...
        "Call this when you have reached the final answer.");
    tools.openAI = [tools.openAI, finalAnswer];

    % Add utility tools (current directory).
    tools = addUtilityTools(tools);
  
    % Tell the AI agent to play nice. Use one of the simplier language
    % models because this is simple problem to solve and smaller models use
    % fewer resources.
    systemPrompt = "You are a helpful AI agent.";
    llm = openAIChat(systemPrompt,ModelName="gpt-4.1-mini", ...
        Tools=tools.openAI);

    % Initialize the message history for the AI agent's responses
    history = messageHistory;

    % Add the task prompt to the message history.
    history = addUserMessage(history,prompt);

    % maxSteps is candidate for an optional input to taskOpenAI.
    maxSteps = 10;
    stepCount = 0;
    problemSolved = false;

    % Infinite loop ... until the agent reaches a final answer or uses the
    % maximum number of alloted steps.
    while ~problemSolved
        if stepCount >= maxSteps
            error("Agent stopped after reaching maximum step limit (%d).",maxSteps);
        end
        stepCount = stepCount + 1;

        %
        % Begin the ReAct interaction pattern: Plan, Act, Observe.
        %

        % Plan
        history = addUserMessage(history,"Plan your single next step concisely.");
        [thought,completeOutput] = generate(llm,history,ToolChoice="none");
        disp("[Thought] " + thought);
        history = addResponseMessage(history,completeOutput);

        % Act
        history = addUserMessage(history,"Execute the next step.");
        [~,completeOutput] = generate(llm,history,ToolChoice="required");
        history = addResponseMessage(history,completeOutput);
        actions = completeOutput.tool_calls;

        % If the agent is invoking the "finalAnswer" tool, it thinks the
        % task is complete.
        if isscalar(actions) && strcmp(actions(1).function.name,"finalAnswer")
            history = addToolMessage(history,actions.id,"finalAnswer","Final answer below");
            history = addUserMessage(history,"Return the final answer as a statement.");
            response = generate(llm,history,ToolChoice="none");
            problemSolved = true;
        else
            % One or more tools must be invoked to complete this step.
            % Invoke them.
            for i = 1:numel(actions)
                action = actions(i);
                toolName = action.function.name;
                fprintf("[Action] Calling tool '%s' with args: %s\n",toolName,jsonencode(action.function.arguments));
                observation = evaluateToolCall(action,tools);
                fprintf("[Observation] Result from tool '%s': %s\n",toolName,jsonencode(observation));
                history = addToolMessage(history,action.id,toolName,"Observation: " + jsonencode(observation));
            end
        end
    end
end

