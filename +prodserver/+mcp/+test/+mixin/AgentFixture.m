classdef (Abstract) AgentFixture < matlab.unittest.fixtures.Fixture
%AgentFixture Run an LLM agent CLI, through devai, against MCP servers.
%
%     agent = test.applyFixture(prodserver.mcp.test.mixin.ClaudeAgent( ...
%         "primes", "http://localhost:9910/primeSequence/mcp"));
%     result = agent.run("Generate the first 20 balanced primes.");
%     result.answer     % the agent's final reply
%     result.calls      % its calls to the named servers, in order made
%     result.output     % everything the agent printed
%
%   Each call is a struct with fields server, tool, failed and error (the
%   failed call's result, or ""). The agent runs in Folder, a temporary
%   folder unless given, so a prompt that names a file in "my working
%   directory" finds it there. A prompt can't contain a double quote: it
%   is passed to the agent in double quotes on the command line.
%
%   Subclasses ClaudeAgent, GeminiAgent and CodexAgent write the agent's
%   MCP configuration, build its command and read its JSON output. Check
%   AgentFixture.available() before applying one.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = immutable)
        Servers (1,:) string    % MCP server names, as the agent sees them
        Endpoints (1,:) string  % their URLs
    end

    properties (SetAccess = private)
        Folder string           % where the agent runs
    end

    methods
        function fix = AgentFixture(servers, endpoints, opts)
            arguments
                servers (1,:) string
                endpoints (1,:) string
                opts.Folder string = string.empty
            end
            if numel(servers) ~= numel(endpoints)
                error("prodserver:mcp:test:AgentServers", ...
                    "%d server names but %d endpoints.", ...
                    numel(servers), numel(endpoints));
            end
            fix.Servers = servers;
            fix.Endpoints = endpoints;
            fix.Folder = opts.Folder;
            fix.SetupDescription = "Configure " + class(fix) + ...
                " for the MCP servers " + strjoin(servers, ", ") + ".";
        end

        function setup(fix)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            if isempty(fix.Folder)
                fix.Folder = string(fix.applyFixture( ...
                    TemporaryFolderFixture).Folder);
            end
            fix.writeConfig();
        end

        function result = run(fix, prompt)
        %run Give the agent PROMPT and wait for it to finish.
            arguments
                fix
                prompt (1,1) string
            end
            if contains(prompt, '"')
                error("prodserver:mcp:test:AgentPrompt", ...
                    "A prompt can't contain a double quote: %s", prompt);
            end
            if ispc
                inFolder = sprintf('cd /d "%s" && ', fix.Folder);
            else
                inFolder = sprintf('cd "%s" && ', fix.Folder);
            end
            [status, output] = system(string(inFolder) + fix.command(prompt));
            output = string(output);
            if status ~= 0
                error("prodserver:mcp:test:AgentFailed", ...
                    "%s exited with status %d: %s", ...
                    class(fix), status, output);
            end
            [answer, calls] = fix.parse(output);
            calls = calls(ismember(string({calls.server}), fix.Servers));
            result = struct("answer", answer, "calls", calls, ...
                "output", output);
        end
    end

    methods (Static)
        function tf = available()
        %available True if devai, which launches every agent, is on PATH.
            [status, ~] = system('devai version');
            tf = status == 0;
        end
    end

    methods (Abstract, Access = protected)
        % Write the agent's MCP configuration for Servers and Endpoints.
        writeConfig(fix)
        % The command that runs the agent on PROMPT, from Folder.
        cmd = command(fix, prompt)
        % The agent's final reply and its calls, to any server.
        [answer, calls] = parse(fix, output)
    end

    methods (Static, Access = protected)
        function events = jsonLines(output)
        %jsonLines The JSON objects in OUTPUT, one per line. The CLIs print
        %   warnings among them, which are skipped.
            events = {};
            for line = splitlines(string(output))'
                if ~startsWith(strtrim(line), "{")
                    continue
                end
                try
                    events{end+1} = jsondecode(line); %#ok<AGROW>
                catch
                end
            end
        end

        function calls = noCalls()
            calls = struct("server", {}, "tool", {}, "failed", {}, ...
                "error", {});
        end

        function call = newCall(server, tool)
            call = struct("server", string(server), "tool", string(tool), ...
                "failed", false, "error", "");
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fx1, fx2)
            tf = isequal(fx1.Servers, fx2.Servers) && ...
                isequal(fx1.Endpoints, fx2.Endpoints) && ...
                isequal(fx1.Folder, fx2.Folder);
        end
    end

end
