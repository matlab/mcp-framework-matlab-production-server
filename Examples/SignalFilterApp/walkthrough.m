%% Signal Filter App
% Give an MCP tool its own interactive view: an MCP App that plots the
% signal cleaned by |cleanSignal|, inside the chat. Building the view needs
% Node.js; showing it needs a host that supports MCP Apps, such as VS Code
% with GitHub Copilot.

% Copyright 2026 The MathWorks, Inc.

% Deploy to this MATLAB Production Server unless another one already
% specified.
if exist("mpsServer","var") == false || isempty(mpsServer)
    mpsServer = "http://localhost:9910";
end

exampleFolder = fileparts(mfilename("fullpath"));
appFolder = fullfile(exampleFolder, "app");
app = fullfile(appFolder, "dist", "mcp-app.html");

%% Build the View
% The view is HTML and TypeScript, in the |app| folder. Vite builds it into
% one HTML file. The build tools are listed in Examples/package.json, and
% npm installs them in Examples/node_modules, which every example app
% shares. Build the view only if it isn't built yet.

if ~isfile(app)
    here = cd(fullfile(exampleFolder, ".."));
    restore = onCleanup(@() cd(here));
    if system("npm install") ~= 0
        error("Could not install the build tools. Is Node.js installed?")
    end
    cd(appFolder)
    if system("npx vite build") ~= 0
        error("Could not build the view.")
    end
    clear restore
end

%% Build and Deploy the Server
% The |app| option serves the view as a |ui://| resource, links it to the
% tool, and adds the |uri2json| tool the view uses to read the signals.
% Only clients that support MCP Apps are offered |uri2json|, so the tool
% list below doesn't show it.

[ctf, endpoint] = prodserver.mcp.build("cleanSignal", app=app, ...
    server=mpsServer);

%% Verify Deployment

prodserver.mcp.ping(endpoint)
resources = prodserver.mcp.list(endpoint, "Resource");
cellfun(@(r) string(r.uri) + "  " + string(r.mimeType), resources)
tools = prodserver.mcp.list(endpoint, "Tool");
cellfun(@(t) string(t.name), tools)

%% Call the Tool
% The tool works from MATLAB as before. MATLAB doesn't show the view.

outputFolder = fullfile(pwd, "output");
if ~isfolder(outputFolder), mkdir(outputFolder); end
noisyURL = "file:" + fullfile(exampleFolder, "openloopVoltage.csv");
cleanURL = "file:" + fullfile(outputFolder, "openloopVoltage_clean.csv");

prodserver.mcp.call(endpoint, "cleanSignal", noisyURL, 60, cleanURL=cleanURL)

%% Connect VS Code
% Create .vscode/mcp.json in your project:
%
%   {
%     "servers": {
%       "cleanSignal": {
%         "url": "http://localhost:9910/cleanSignal/mcp",
%         "type": "http"
%       }
%     }
%   }
%
% Then, in Copilot Chat in agent mode, try this prompt:
%
%   Remove the 60 Hz periodic noise from the signal in openloopVoltage.csv
%   in the SignalFilterApp example folder.
%
% VS Code shows the view in the chat. Choose Original, Clean or Both to
% change the plot, or enter another frequency and choose Add pass.
