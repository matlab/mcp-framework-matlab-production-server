classdef tClaudeProtocol < tLLMProtocol
%tClaudeProtocol Verify Claude connects to and calls a deployed MCP tool.

% Copyright 2026 The MathWorks, Inc.

    methods (Access = protected)

        function writeMCPConfig(test)
            cfg = struct();
            cfg.mcpServers.(test.toolName) = struct( ...
                'type', 'http', ...
                'headers', struct('Authorization', 'Bearer none'), ...
                'url', test.endpoint);
            test.configFile = fullfile(test.configFolder, 'mcp.json');
            fid = fopen(test.configFile, 'w');
            closeFile = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(cfg));
        end

        function output = runAgent(test, prompt)
            cmd = sprintf( ...
                'devai launch -- claude --print "%s" --mcp-config "%s" --strict-mcp-config --allowedTools "mcp__%s__%s"', ...
                prompt, test.configFile, test.toolName, test.toolName);
            [status, output] = system(cmd);
            test.assertEqual(status, 0, ...
                "devai launch claude failed: " + output);
        end

    end

end
