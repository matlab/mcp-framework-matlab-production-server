# openai_mcp_wrapper.py
# Generate an MCP wrapper for a MATLAB function using OpenAI.
#
# Usage:
#    openai_mcp_wrapper.py --for <function> -- in <folder> 

# Copyright 2025, The MathWorks, Inc.

import argparse
from agents import Agent, Runner

parser = argparse.ArgumentParser(description="Generate an MCP wrapper for a MATLAB function using OpenAI")
parser.add_argument("--fcn", type=str, help="Path to MATLAB function.")
parser.add_argument("--in", type=str, help="Path to folder in which to generate wrapper.")
parser.add_argument("--prompt", type=str, help="Path to prompt used to generate wrapper.")
args = parser.parse_args()

agent = Agent(name="Assistant", instructions="You are a helpful assistant")

# Concatenate the input file to the prompt and send the whole mess to OpenAI.

try:
    with open(args.prompt, 'r') as prompt_file:
        prompt = prompt_file.readlines()

        with open(args.fcn, 'r') as fcn_file:
            fcn = fcn_file.readlines()
            prompt = prompt + fcn

    result = Runner.run_sync(agent, prompt) 
    print(result)

except FileNotFoundError:
    print(f"Prompt file {args.prompt} not found.")
except Exception as e:
    print(e)



