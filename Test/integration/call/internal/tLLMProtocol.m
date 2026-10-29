classdef (Abstract) tLLMProtocol < prodserver.mcp.test.base.MCPCaller
%tLLMProtocol Verify that a live LLM agent session negotiates and uses
%   each supported MCP protocol to call a deployed tool.
%
%   Subclasses implement writeMCPConfig and runAgent for each LLM CLI.
%   Requires MW_MCP_MPS_TEST_SERVER and devai on PATH.

% Copyright 2026 The MathWorks, Inc.

    properties
        endpoint
        archive
        toolName
        serverName
        configFile
        configFolder
        sequence
        seqLen = 13
        seqType = "Eisenstein"
    end

    methods (TestClassSetup)

        function requireDevai(test)
            [status, ~] = system('devai version');
            test.assumeTrue(status == 0, ...
                'devai is not available on PATH');
        end

        function buildAndDeploy(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Gemini hates _ in server names. So just jam all the UUID
            % sections together.
            %
            % Also, Gemini restricts tool names to 64 characters, and adds
            % some of its own, so shorten the UUID.
            uuid = replace(string(matlab.lang.internal.uuid), "-","");
            uuid = extractBefore(uuid,9);
            test.serverName = "primes";
            test.toolName = "primeSequence" + uuid;
            test.archive = "LLMProtocol" + uuid;

            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive( ...
                test.server, test.archive));

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);

            examplesDir = fullfile(fileparts(mfilename("fullpath")), ...
                "..", "..", "..", "..", "Examples", "Primes");
            addpath(examplesDir);
            cleanPath = onCleanup(@() rmpath(examplesDir));

            ctf = prodserver.mcp.build("primeSequence", ...
                folder=tfolder.Folder, ...
                archive=test.archive, ...
                tool=test.toolName, ...
                example=@() primeSequence(test.seqLen, test.seqType));
            test.assertNotEmpty(ctf);

            test.sequence = primeSequence(test.seqLen, test.seqType);

            test.endpoint = prodserver.mcp.deploy( ...
                ctf, test.host, test.port);
        end

        function setupConfig(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            cfgFolder = TemporaryFolderFixture;
            applyFixture(test, cfgFolder);
            test.configFolder = cfgFolder.Folder;

            test.writeMCPConfig();
        end

    end

    methods (Test)

        function tAgentCallsTool(test)
        %tAgentCallsTool Verify the agent calls the deployed tool and
        %   returns a plausible result.
            prompt = sprintf( ...
                "Use the %s tool to determine the first %d Eisenstein primes. " + ...
                "Return only the numeric result. %s", ...
                test.toolName, test.seqLen, augmentPrompt(test));
            output = test.runAgent(prompt);

            seqPat = wildcardPattern;
            for n = 1:test.seqLen
                seqPat = seqPat + string(test.sequence(n)) + ...
                    wildcardPattern(Except=digitsPattern);
            end

            test.verifyTrue(contains(output, seqPat), ...
                "Output should contain the Eisenstein prime sequence");
        end

        function tProtocolMetricIncremented(test)
        %tProtocolMetricIncremented Verify that the tool call metric
        %   is incremented after an agent session.
            import prodserver.mcp.MCPConstants

            toolMetric = MCPConstants.MCPMetricPrefix + ...
                test.toolName + MCPConstants.MCPToolCallSuffix;

            catalog = prodserver.mcp.metrics(test.endpoint);
            entries = catalog.name(toolMetric);
            if isempty(entries)
                before = 0;
            else
                before = entries(1).value;
            end

            % As many primes as tAgentCallsTool asks for: an agent knows the
            % first few without the tool, and answers itself.
            prompt = sprintf( ...
                "Use the %s tool to determine the first %d Eisenstein primes. %s", ...
                test.toolName, test.seqLen, augmentPrompt(test));
            test.runAgent(prompt);

            after = before;
            for attempt = 1:20 
                catalog = prodserver.mcp.metrics(test.endpoint);
                entries = catalog.name(toolMetric);
                if ~isempty(entries)
                    after = entries(1).value;
                    if after > before
                        break
                    end
                end
                pause(1);
            end

            test.verifyGreaterThan(after, before, ...
                "Tool call metric should increment after agent session");
        end

        function tProtocolVersionInMetric(test)
        %tProtocolVersionInMetric Verify that a per-protocol metric
        %   exists after a tool call, identifying which MCP protocol
        %   version was used.
            import prodserver.mcp.MCPConstants

            prompt = sprintf( ...
                "Use the %s tool to determine the first %d Gaussian primes. %s", ...
                test.toolName, test.seqLen, augmentPrompt(test));
            test.runAgent(prompt);

            toolMetric = MCPConstants.MCPMetricPrefix + ...
                test.toolName + MCPConstants.MCPToolCallSuffix;

            found = false;
            for attempt = 1:20 
                catalog = prodserver.mcp.metrics(test.endpoint);
                for p = test.Protocols
                    entries = catalog.name(toolMetric + "_" + replace(p, "-", "_"));
                    if ~isempty(entries) && entries(1).value > 0
                        found = true;
                        break
                    end
                end
                if found
                    break
                end
                pause(1);
            end

            test.verifyTrue(found, ...
                "A per-protocol tool call metric should exist for one of: " + ...
                strjoin(test.Protocols, ", "));
        end

    end

    methods (Abstract, Access = protected)
        writeMCPConfig(test)
        output = runAgent(test, prompt)
    end

    methods (Access = protected)
        function str = augmentPrompt(~)
        %augmentPrompt Instructions added to every prompt. An agent that can
        %   work out the answer itself may not call the tool at all, and
        %   these tests count the calls.
            str = "DO NOT search files, look for code, or run glob " + ...
                "patterns. DO NOT search the web. Only call the MCP " + ...
                "tool. Do not figure this out yourself either.";
        end
    end

end
