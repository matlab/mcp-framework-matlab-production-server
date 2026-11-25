classdef GeminiAgent < prodserver.mcp.test.mixin.AgentFixture
%GeminiAgent Run Gemini CLI, through devai, against MCP servers.
%
%   Gemini names a server's tools mcp_<server>_<tool>, and rejects a
%   server name with an underscore or a tool name over 64 characters, so
%   keep both short and without underscores. Its stream-json output lists
%   each tool call and result. See AgentFixture.

% Copyright 2026 The MathWorks, Inc.

    methods
        function fix = GeminiAgent(servers, endpoints, opts)
            arguments
                servers (1,:) string
                endpoints (1,:) string
                opts.Folder string = string.empty
            end
            fix@prodserver.mcp.test.mixin.AgentFixture(servers, endpoints, ...
                Folder=opts.Folder);
        end
    end

    methods (Access = protected)

        function writeConfig(fix)
        % A project settings file, .gemini/settings.json in the folder
        % Gemini runs in. Not a system settings file
        % (GEMINI_CLI_SYSTEM_SETTINGS_PATH): Gemini skips one in a folder
        % the user can write to, which a temporary folder always is, and
        % then has no MCP server at all.
            cfg = struct();
            for k = 1:numel(fix.Servers)
                cfg.mcpServers.(fix.Servers(k)) = struct( ...
                    'httpUrl', fix.Endpoints(k), ...
                    'trust', true);
            end
            folder = fullfile(fix.Folder, '.gemini');
            if ~isfolder(folder)
                mkdir(folder);
                fix.addTeardown(@() rmdir(folder, 's'));
            end
            writelines(jsonencode(cfg), fullfile(folder, 'settings.json'));
        end

        function cmd = command(~, prompt)
        % Gemini reads project settings only in a trusted workspace, and
        % --skip-trust alone doesn't make it trusted in a non-interactive
        % (-p) session.
            if ispc
                trust = "set GEMINI_CLI_TRUST_WORKSPACE=true&& ";
            else
                trust = "GEMINI_CLI_TRUST_WORKSPACE=true ";
            end
            cmd = trust + sprintf("devai launch -- gemini --skip-trust " + ...
                "--output-format stream-json -p ""%s""", prompt);
        end

        function [answer, calls] = parse(fix, output)
        % tool_use and tool_result events share a tool_id; the assistant's
        % reply comes in message events, in pieces.
            % Without its MCP server Gemini answers from what it knows, and
            % a test of the tool's answer would pass without the tool.
            if contains(output, "No MCP servers configured") || ...
                    contains(output, "Skipping system settings file")
                error("prodserver:mcp:test:AgentNoServer", ...
                    "Gemini has no MCP server: %s", output);
            end
            answer = "";
            calls = fix.noCalls();
            ids = string.empty;
            for event = fix.jsonLines(output)
                ev = event{1};
                if ~isfield(ev, "type")
                    continue
                end
                switch ev.type
                    case "tool_use"
                        [server, tool] = fix.splitName(string(ev.tool_name));
                        calls(end+1) = fix.newCall(server, tool); %#ok<AGROW>
                        ids(end+1) = ev.tool_id; %#ok<AGROW>
                    case "tool_result"
                        n = find(ids == string(ev.tool_id), 1);
                        if ~isempty(n) && ev.status ~= "success"
                            calls(n).failed = true;
                            if isfield(ev, "error")
                                calls(n).error = string(jsonencode(ev.error));
                            elseif isfield(ev, "output")
                                calls(n).error = string(ev.output);
                            end
                        end
                    case "message"
                        if ev.role == "assistant"
                            answer = answer + string(ev.content);
                        end
                end
            end
        end

    end

    methods (Access = private)
        function [server, tool] = splitName(fix, name)
        %splitName The server and tool in mcp_<server>_<tool>, for one of
        %   the named servers; "" and NAME for any other tool.
            server = "";
            tool = name;
            for s = fix.Servers
                prefix = "mcp_" + s + "_";
                if startsWith(name, prefix)
                    server = s;
                    tool = extractAfter(name, prefix);
                    return
                end
            end
        end
    end

end
