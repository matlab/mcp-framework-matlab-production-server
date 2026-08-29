%% Principal Stress Analysis
% Build your first MCP tool from a MATLAB function, deploy it to MATLAB
% Production Server, and call it from an AI agent.

% Copyright 2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Test the Function Locally
% |principalStress| computes principal stresses from a 2D stress state
% using Mohr's circle. Verify it works before deploying.

sigma_max = principalStress([120 -50 80], "max")
sigma_min = principalStress([120 -50 80], "min")
tau_max = principalStress([120 -50 80], "maxShear")

%% Build the MCP Tool
% Package |principalStress| into a deployable archive. Pass an example call
% so the framework determines input and output types automatically.

ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));

%% Deploy to MATLAB Production Server
% Upload the archive to a running instance at localhost:9910.

endpoint = prodserver.mcp.deploy(ctf, mpsServer);

%% Verify Deployment
% Confirm the server is responsive and hosts the expected tool.

prodserver.mcp.ping(endpoint)
prodserver.mcp.exist(endpoint, "principalStress", "Tool")

%% Test with MCP Protocol
% Call the tool end-to-end using the MCP protocol, just as an LLM will.

sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "max")
sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "min")
sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "maxShear")

%% Connect an MCP Client
% The tool is now available at the endpoint URL. Configure your MCP client
% (Claude Code, Claude Desktop, VS Code) to connect to:
%
%   http://localhost:9910/principalStress/mcp
%
% Then try this prompt:
%
%   A point in a steel beam is under 120 MPa normal stress in X, 50 MPa
%   compressive stress in Y, and 80 MPa shear. What are the principal
%   stresses and maximum shear stress? Will it yield if the steel has a
%   250 MPa yield strength?


