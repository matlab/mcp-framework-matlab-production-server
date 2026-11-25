%% Prime Sequences
% Build an MCP tool from |primeSequence|, which generates four types of
% prime number sequences.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if exist("mpsServer","var") == false || isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Test the Function Locally
% |primeSequence| returns a vector of primes matching a given sequence
% type: balanced, Eisenstein, Gaussian, or isolated.

eb = primeSequence(11, "balanced")
ee = primeSequence(9, "eisenstein")

%% Build the MCP Tool
% Package |primeSequence| as an MCP tool. Give build an example call so it
% can generate a good description of the tool's inputs and outputs.

ctf = prodserver.mcp.build("primeSequence", example=@()primeSequence(17,"Isolated"));

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
assert(all(bpr == eb), "Incorrect balanced sequence")

epr = prodserver.mcp.call(endpoint, "primeSequence", 9, "eisenstein")'
assert(all(epr == ee), "Incorrect Eisenstein sequence")

%% Connect an MCP Client
% Configure your MCP client to connect to:
%
%   http://localhost:9910/primeSequence/mcp
%
% Then try this prompt:
%
%   Generate the first 20 balanced primes and the first 20 isolated primes.
%   Which primes appear in both sequences?


