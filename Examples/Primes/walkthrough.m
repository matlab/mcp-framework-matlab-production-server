%% Prime Sequences
% Build an MCP tool from |primeSequence|, which generates four types of
% prime number sequences.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Test the Function Locally
% |primeSequence| returns a vector of primes matching a given sequence
% type: balanced, Eisenstein, Gaussian, or isolated.

primeSequence(5, "balanced")
primeSequence(5, "eisenstein")
primeSequence(5, "gaussian")
primeSequence(5, "isolated")

%% Build the MCP Tool
% Package |primeSequence| as an MCP tool. The output is a small numeric
% vector, so no wrapper function is needed.

ctf = prodserver.mcp.build("primeSequence", wrapper="None");

%% Deploy to MATLAB Production Server
% Upload the archive to a running instance at localhost:9910.

endpoint = prodserver.mcp.deploy(ctf, mpsServer);

%% Verify Deployment
% Confirm the server is responsive and hosts the expected tool.

prodserver.mcp.ping(endpoint)
prodserver.mcp.exist(endpoint, "primeSequence", "Tool")

%% Test with MCP Protocol
% Call the tool end-to-end using the MCP protocol.

bpr = prodserver.mcp.call(endpoint, "primeSequence", 11, "balanced")'
epr = prodserver.mcp.call(endpoint, "primeSequence", 9, "eisenstein")'

%% Connect an MCP Client
% Configure your MCP client to connect to:
%
%   http://localhost:9910/primeSequence/mcp
%
% Then try this prompt:
%
%   Generate the first 20 balanced primes and the first 20 isolated primes.
%   Which primes appear in both sequences?


