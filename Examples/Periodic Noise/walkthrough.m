%% Removing Periodic Noise
% Build an MCP tool that removes periodic noise from a signal. This example
% demonstrates how the framework auto-generates a wrapper function when
% parameters are large.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if exist("mpsServer","var") == false || isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

%% Test the Function Locally
% |cleanSignal| applies a Butterworth notch filter to remove periodic noise
% at a specified frequency.

data = readmatrix("openloopVoltage.csv");
clean = cleanSignal(data, 60);
figure
plot([data, clean]);
legend("Noisy","Clean");
title("Open-Loop Voltage: 60 Hz Noise Removal");

%% Build the MCP Tool
% The |noisy| input is a large array (no size constraint in arguments block),
% so the framework auto-generates a wrapper that externalizes it as a file URL.
% The scalar |period| passes directly. Argument blocks fully specify types, so
% no example call is needed.

[ctf, endpoint] = prodserver.mcp.build("cleanSignal", server=mpsServer);

%% Verify Deployment

prodserver.mcp.ping(endpoint)
prodserver.mcp.exist(endpoint, "cleanSignal", "Tool")

%% Test with MCP Protocol
% Call the tool using file URLs, just as an LLM would.

noisyURL = "file:" + fullfile(pwd, "openloopVoltage.csv");
cleanURL = "file:" + fullfile(pwd, "cleanOpenLoop.csv");

prodserver.mcp.call(endpoint, "cleanSignal", noisyURL, 60, cleanURL=cleanURL)

%% Display the Result

result = readmatrix("cleanOpenLoop.csv");
figure
plot([data, result]);
legend("Noisy","Clean (from MCP tool)");
title("Filtered Signal via MCP Tool");

%% Connect an MCP Client
% Configure your client to connect to:
%
%   http://localhost:9910/cleanSignal/mcp
%
% Then try this prompt:
%
%   Remove the 60 Hz periodic noise from the signal in openloopVoltage.csv
%   in my working directory. Save the result as openloopVoltage_clean.csv.


