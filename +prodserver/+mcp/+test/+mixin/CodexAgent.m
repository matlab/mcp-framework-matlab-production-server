classdef CodexAgent < prodserver.mcp.test.mixin.AgentFixture
%CodexAgent Run Codex CLI, through devai, against MCP servers.
%
%   Codex gets its MCP servers on the command line. Its --json output
%   reports each MCP tool call as an mcp_tool_call item. See AgentFixture.

% Copyright 2026 The MathWorks, Inc.

    methods
        function fix = CodexAgent(servers, endpoints, opts)
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

        function writeConfig(~)
            % Setting the config folder overrides login authorization
            % methods and causes devai to fail. So pass MCP server info via
            % command line arguments instead.
        end

        function cmd = command(fix, prompt)
            servers = "";
            for k = 1:numel(fix.Servers)
                servers = servers + sprintf( ...
                    " -c ""mcp_servers.%s.url=%s""" + ...
                    " -c ""mcp_servers.%s.default_tools_approval_mode=auto""", ...
                    fix.Servers(k), fix.Endpoints(k), fix.Servers(k));
            end
            cmd = sprintf("devai launch -- codex exec --json ""%s""", prompt) + ...
                servers + " --sandbox danger-full-access --skip-git-repo-check";
            if ispc
                cmd = cmd + " <nul";
            end
        end

        function [answer, calls] = parse(fix, output)
        % A completed mcp_tool_call item has the server, tool and status;
        % the last agent_message item is the reply.
            answer = "";
            calls = fix.noCalls();
            for event = fix.jsonLines(output)
                ev = event{1};
                if ~isfield(ev, "type") || ev.type ~= "item.completed" || ...
                        ~isfield(ev, "item")
                    continue
                end
                item = ev.item;
                switch item.type
                    case "mcp_tool_call"
                        call = fix.newCall(item.server, item.tool);
                        if item.status ~= "completed" || ...
                                (isfield(item, "error") && ~isempty(item.error))
                            call.failed = true;
                            if isfield(item, "error") && ~isempty(item.error)
                                call.error = string(jsonencode(item.error));
                            end
                        end
                        calls(end+1) = call; %#ok<AGROW>
                    case "agent_message"
                        answer = string(item.text);
                end
            end
        end

    end

end
