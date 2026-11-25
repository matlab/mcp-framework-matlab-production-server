# Examples

Complete walkthroughs from MATLAB code to LLM prompt. Each example builds a working MCP tool, deploys it, verifies the deployment, and demonstrates how an AI agent uses it.

The examples deploy to a MATLAB Production Server instance at `http://localhost:9910` with archive management turned on: without it, `deploy` can't upload. To create and configure one, see [Set Up a Server](../docs/getting-started.md#set-up-a-server).

| Example | What it demonstrates | Complexity |
| :--- | :--- | :--- |
| [Principal Stress](./PrincipalStress/walkthrough.md) | Your first tool — build, deploy, verify, connect a client | Introductory |
| [Prime Sequences](./Primes/walkthrough.md) | Single-function tool with string and numeric inputs | Introductory |
| [Periodic Noise](./Periodic%20Noise/walkthrough.md) | Large-data tool with a generated wrapper function | Intermediate |
| [Signal Filter App](./SignalFilterApp/walkthrough.md) | An MCP App: an interactive view of a tool's result, shown in the chat | Advanced |
| [Earthquake Trajectories](./Earthquake/walkthrough.md) | Custom wrapper with table import and JPEG output | Intermediate |
| [Materials Engineering](./Materials/walkthrough.md) | Multi-tool server with MCP Resources for reference data | Intermediate |
| [Structured Data](./StructuredData/walkthrough.md) | Struct parameters described with `%#schema` pragma | Intermediate |
| [Multi-Tool Fractals](./MultiTool/walkthrough.md) | Seven tools on one server with renamed tools | Advanced |
| [Wire Encoding](./WireEncoding/walkthrough.md) | Preserving vector orientation, complex numbers, NaN, and integer types | Advanced |
| [MATLAB + OpenAI](./MATLABOpenAI/walkthrough.md) | Building an MCP host in MATLAB using LLMs with MATLAB | Advanced |
| [Dev and Test](./DevAndTest/walkthrough.md) | Interactive debugging with the development server | Advanced |

Start with [Principal Stress](./PrincipalStress/walkthrough.md) if you have not built a tool before. It follows the same workflow as [Getting Started](../docs/getting-started.md) and takes about five minutes.

--- Copyright 2026 The MathWorks, Inc. ---
