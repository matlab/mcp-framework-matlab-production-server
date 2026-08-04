classdef tDiscovery < matlab.unittest.TestCase

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
    end

    methods (TestMethodSetup)

        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
        end

    end

    methods(Test)

        function generatesJSON(test)
        % discoverySignatures creates a valid JSON file.

            import prodserver.mcp.MCPConstants

            archive = "testArchive";
            filePath = prodserver.mcp.internal.discoverySignatures( ...
                test.tempFolder, archive);

            test.verifyEqual(exist(filePath,"file"), 2, ...
                "Discovery signatures file not created");
            test.verifyTrue(endsWith(filePath, ...
                archive + "_functionSignatures.json"), ...
                "Unexpected file name");

            raw = string(fileread(filePath));
            test.verifyTrue(contains(raw, '"_schemaVersion"'), ...
                "_schemaVersion key missing");
            test.verifyTrue(contains(raw, MCPConstants.DiscoverySchemaVersion), ...
                "Schema version value mismatch");
            test.verifyTrue(contains(raw, ...
                '"prodserver.mcp.internal.mcpHandler"'), ...
                "mcpHandler entry missing");
            test.verifyTrue(contains(raw, '"purpose"'), ...
                "purpose field missing");
            test.verifyTrue(contains(raw, "MCP"), ...
                "purpose should mention MCP");
        end

        function handlerSignature(test)
        % Verify mcpHandler input/output structure.

            archive = "sigTest";
            filePath = prodserver.mcp.internal.discoverySignatures( ...
                test.tempFolder, archive);

            raw = string(fileread(filePath));

            test.verifyTrue(contains(raw, '"inputs"'), "inputs missing");
            test.verifyTrue(contains(raw, '"outputs"'), "outputs missing");
            test.verifyTrue(contains(raw, '"request"'), "Input name");
            test.verifyTrue(contains(raw, '"response"'), "Output name");
            test.verifyTrue(contains(raw, '"struct"'), ...
                "struct type missing");
        end

        function buildIncludesDiscovery(test)
        % build with discovery=true generates the signatures file.

            test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());

            archive = "discoveryOn";
            prodserver.mcp.build("toyToolOne", stop="Routes", ...
                folder=test.tempFolder, archive=archive, discovery=true);

            sigFile = fullfile(test.tempFolder, ...
                archive + "_functionSignatures.json");
            test.verifyEqual(exist(sigFile,"file"), 2, ...
                "Signatures file should exist when discovery=true");
        end

        function buildExcludesDiscovery(test)
        % build with discovery=false does not generate the signatures file.

            test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());

            archive = "discoveryOff";
            prodserver.mcp.build("toyToolOne", stop="Routes", ...
                folder=test.tempFolder, archive=archive, discovery=false);

            sigFile = fullfile(test.tempFolder, ...
                archive + "_functionSignatures.json");
            test.verifyEqual(exist(sigFile,"file"), 0, ...
                "Signatures file should not exist when discovery=false");
        end

    end
end
