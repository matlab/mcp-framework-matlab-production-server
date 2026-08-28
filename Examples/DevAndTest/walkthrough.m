%% Debugging MCP Tools with Dev and Test
% Use the MATLAB |productionServerArchiveCompiler| app to run a local
% development server with full interactive debugging.

% Copyright 2025-2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server.
mpsServer = "http://localhost:9910";

%% Build Routes for the Development Server
% Generate routes without creating a full CTF archive. The |stop| option
% halts the build process after route generation.

prodserver.mcp.build("primeSequence", wrapper="None", stop="Routes");
copyfile("deploy/McpServices.mat", ".");
setenv("PRODSERVER_ROUTES_FILE", "deploy/dev_test_routes.json");

%% Launch the Development Server
% Open |productionServerArchiveCompiler| and create a new project.
% Add the MCP handlers as exported functions and set the archive name to
% match |primeSequence|.

productionServerArchiveCompiler

%% Start the Server and Set Breakpoints
% Press Test Client, then the green start arrow. Set breakpoints in
% |primeSequence.m| or in the MCP framework handlers as needed.
%
% The server status panel should show that handlers are loaded and the
% routes file is recognized.

%% Test from a Second MATLAB
% In a separate MATLAB desktop, call the tool via MCP protocol:
%
%   seq = prodserver.mcp.call("http://localhost/primeSequence/mcp", ...
%       "primeSequence", 11, "balanced")
%
% The call routes through the development server. Breakpoints will trigger
% and you can inspect variables, step through code, and debug interactively.


