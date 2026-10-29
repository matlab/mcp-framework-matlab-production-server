classdef tGeminiProtocol < tLLMProtocol
%tGeminiProtocol Verify Gemini connects to and calls a deployed MCP tool.

% Copyright 2026 The MathWorks, Inc.

    methods (Access = protected)

        function writeMCPConfig(test)
        % A project settings file, .gemini/settings.json in the folder
        % Gemini runs in. Not a system settings file
        % (GEMINI_CLI_SYSTEM_SETTINGS_PATH): Gemini skips one in a folder
        % the user can write to, which a temporary folder always is, and
        % then has no MCP server at all.
            cfg = struct();
            cfg.mcpServers.(test.serverName) = struct( ...
                'httpUrl', test.endpoint, ...
                'trust', true);
            folder = fullfile(test.configFolder, '.gemini');
            if ~isfolder(folder)
                mkdir(folder);
            end
            test.configFile = fullfile(folder, 'settings.json');
            fid = fopen(test.configFile, 'w');
            closeFile = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(cfg));
        end

        function output = runAgent(test, prompt)
        % Run in the folder that holds .gemini. Gemini reads project
        % settings only in a trusted workspace, and --skip-trust alone
        % doesn't make it trusted in a non-interactive (-p) session.
            dosCmd = ['cd /d "%s" && set GEMINI_CLI_TRUST_WORKSPACE=true&& ' ...
                'devai launch -- gemini --skip-trust -p "%s"'];
            bashCmd = ['cd "%s" && GEMINI_CLI_TRUST_WORKSPACE=true ' ...
                'devai launch -- gemini --skip-trust -p "%s"'];
            if ispc
                osCmd = dosCmd;
            else
                osCmd = bashCmd;
            end
            cmd = sprintf(osCmd, test.configFolder, prompt);
            [status, output] = system(cmd);
            test.assertEqual(status, 0, ...
                "devai launch gemini failed: " + output);
            % Without its MCP server Gemini answers from what it knows, and
            % a test of the tool's answer would pass without the tool.
            test.assertFalse(contains(output, "No MCP servers configured") || ...
                contains(output, "Skipping system settings file"), ...
                "Gemini has no MCP server: " + output);
        end

    end

end
