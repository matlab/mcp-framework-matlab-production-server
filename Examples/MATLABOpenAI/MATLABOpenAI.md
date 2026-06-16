# LLMs with MATLAB&reg; 
MATLAB interacts with AI agents via a variety of mechanisms. This example demonstrates how to combine two MATLAB add-ons to enable MATLAB to invoke MCP tools through an AI agent. The [LLMs with MATLAB](https://www.mathworks.com/matlabcentral/fileexchange/163796-large-language-models-llms-with-matlab) add-on connects MATLAB to large language models such as OpenAI's ChatGPT. The MCP Framework for MATLAB Production Server makes MATLAB functions available as MCP tools which these large language models can use.

LLMs with MATLAB provides features with which to build an MCP host in MATLAB. In this example the function `taskOpenAI` is a simple MCP host, capable of interacting with OpenAI language models to process a single prompt. `taskOpenAI` uses the ReAct AI interaction paradigm, which encourages LLMs to examine their own reponses to better plan the mulitple steps needed to solve complex problems.

Note that this example uses the publicly available OpenAI servers and therefore requires network access and consumes OpenAI usage tokens.

## Setup
This example uses the `cleanSignal` tool from the Periodic Noise example. `cleanSignal` must be deployed to an active MATLAB Production Server instance.

1. Build and deploy the [cleanSignal](../Examples/Periodic%20Noise/PeriodicNoise.md) MCP tool as shown.
2. Install the [LLMs with MATLAB](https://www.mathworks.com/matlabcentral/fileexchange/163796-large-language-models-llms-with-matlab) if necessary.
3. Copy openloopVoltage.csv from the Periodic Noise example into your working directory.

# Periodic Noise Example
MCP hosts orchestrate the interaction of multiple MCP tools in response to a user prompt. Configure LLMs with MATLAB to use the [cleanSignal](../Examples/Periodic%20Noise/PeriodicNoise.md), which removes periodic noise of a given frequency from an observed signal. 

```MATLAB
% Obtain the tool definition by querying the MCP server.
mcpTools = prodserver.mcp.list("http://localhost:9910/cleanSignal/mcp","tool");

% Set the prompt
prompt = "Remove the 60Hz periodic noise from the signal in the file openloopVoltage.csv in the current directory. Name the output file openloopVoltage_clean.csv";

% Ask the AI agent to perform the task using the tools.
taskOutput = taskOpenAI(prompt,mcpTools)

% Display the output, the filtered clean signal
result = extract(taskOutput,"openloopVoltage_"+wildcardPattern+".csv");
data = readmatrix(result);
figure
plot(data);
```


## References
The ReAct AI agent interaction paradigm was introduced in 2023:

Shunyu Yao, Jeffrey Zhao, Dian Yu, Nan Du, Izhak Shafran, Karthik Narasimhan, and Yuan Cao. "ReAct: Synergizing Reasoning and Acting in Language Models". ArXiv, 10 March 2023. https://doi.org/10.48550/arXiv.2210.03629.