classdef tCodexProtocol < tLLMProtocol
%tCodexProtocol Verify Codex connects to and calls a deployed MCP tool.

% Copyright 2026 The MathWorks, Inc.

    methods (Access = protected)

        function writeMCPConfig(~)
            % Setting the config folder overrides login authorization
            % methods and causes devai to fail. So pass MCP server info via
            % command line arguments instead. 
        end

        function output = runAgent(test, prompt)
            cmd = sprintf( ...
                'devai launch -- codex exec "%s" -c "mcp_servers.%s.url=%s" -c "mcp_servers.%s.default_tools_approval_mode=auto" --sandbox danger-full-access --skip-git-repo-check', ...
                prompt, test.toolName, test.endpoint, test.toolName);
            if ispc
                cmd = [cmd ' <nul'];
            end
            [status, output] = system(cmd);
            test.assertEqual(status, 0, ...
                "devai launch codex failed: " + output);
        end

    end

end
