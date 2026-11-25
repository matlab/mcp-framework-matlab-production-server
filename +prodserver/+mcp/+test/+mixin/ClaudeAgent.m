classdef ClaudeAgent < prodserver.mcp.test.mixin.AgentFixture
%ClaudeAgent Run Claude Code, through devai, against MCP servers.
%
%   Claude may use every tool on the named servers and read their
%   resources, and nothing else. Its stream-json output lists each tool
%   call and result. See AgentFixture.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        ConfigFile string
    end

    methods
        function fix = ClaudeAgent(servers, endpoints, opts)
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
        % In a folder of its own, not the one Claude runs in: there a
        % .mcp.json would be read too, and --strict-mcp-config reads only
        % this one.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = fix.applyFixture(TemporaryFolderFixture).Folder;
            cfg = struct();
            for k = 1:numel(fix.Servers)
                cfg.mcpServers.(fix.Servers(k)) = struct( ...
                    'type', 'http', ...
                    'headers', struct('Authorization', 'Bearer none'), ...
                    'url', fix.Endpoints(k));
            end
            fix.ConfigFile = fullfile(folder, 'mcp.json');
            writelines(jsonencode(cfg), fix.ConfigFile);
        end

        function cmd = command(fix, prompt)
            allowed = strjoin(["mcp__" + fix.Servers, ...
                "ListMcpResourcesTool", "ReadMcpResourceTool"], ",");
            cmd = sprintf("devai launch -- claude --print ""%s"" " + ...
                "--mcp-config ""%s"" --strict-mcp-config " + ...
                "--allowedTools ""%s"" --output-format stream-json --verbose", ...
                prompt, fix.ConfigFile, allowed);
        end

        function [answer, calls] = parse(fix, output)
        % Tool calls are tool_use items in assistant messages, named
        % mcp__<server>__<tool>; their results are tool_result items in
        % the next user message. The last event, result, has the reply.
            answer = "";
            calls = fix.noCalls();
            ids = string.empty;
            for event = fix.jsonLines(output)
                ev = event{1};
                if ~isfield(ev, "type")
                    continue
                end
                switch ev.type
                    case "system"
                        if isfield(ev, "mcp_servers")
                            fix.requireConnected(ev.mcp_servers);
                        end
                    case "assistant"
                        for item = contentItems(ev)
                            c = item{1};
                            if c.type == "tool_use" && startsWith(c.name, "mcp__")
                                parts = split(string(c.name), "__");
                                calls(end+1) = fix.newCall(parts(2), ...
                                    strjoin(parts(3:end), "__")); %#ok<AGROW>
                                ids(end+1) = c.id; %#ok<AGROW>
                            end
                        end
                    case "user"
                        for item = contentItems(ev)
                            c = item{1};
                            if c.type ~= "tool_result"
                                continue
                            end
                            n = find(ids == string(c.tool_use_id), 1);
                            if ~isempty(n) && isfield(c, "is_error") && c.is_error
                                calls(n).failed = true;
                                calls(n).error = textOf(c.content);
                            end
                        end
                    case "result"
                        if isfield(ev, "result")
                            answer = string(ev.result);
                        end
                end
            end
        end

    end

    methods (Access = private)
        function requireConnected(fix, servers)
            for s = servers(:)'
                if ismember(string(s.name), fix.Servers) && s.status ~= "connected"
                    error("prodserver:mcp:test:AgentNoServer", ...
                        "Claude didn't connect to the MCP server %s: %s.", ...
                        s.name, s.status);
                end
            end
        end
    end

end

function items = contentItems(ev)
%contentItems The content items of a message, as a row cell array:
%   jsondecode makes a column struct array of items with the same fields,
%   a column cell array of items without.
    items = {};
    if isfield(ev, "message") && isfield(ev.message, "content")
        items = ev.message.content;
        if isstruct(items)
            items = num2cell(items(:)');
        elseif iscell(items)
            items = items(:)';
        else
            items = {};
        end
    end
end

function text = textOf(content)
%textOf A tool result's text: a string, or a list of text items.
    if ischar(content) || isstring(content)
        text = string(content);
        return
    end
    if isstruct(content)
        content = num2cell(content);
    end
    text = "";
    for c = content(:)'
        if isfield(c{1}, "text")
            text = text + string(c{1}.text);
        end
    end
end
