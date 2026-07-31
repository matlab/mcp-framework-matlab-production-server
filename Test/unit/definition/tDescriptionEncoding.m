classdef tDescriptionEncoding < matlab.unittest.TestCase
% Tests that wire-encoding messages are correctly placed in tool descriptions.

% Copyright 2026 The MathWorks, Inc.

    properties
        pkgFolder
        paramFolder
    end

    methods (TestClassSetup)

        function setupPaths(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            test.pkgFolder = fullfile(testFolder,"../../..");
            test.paramFolder = fullfile(test.pkgFolder,"Test","tools","parameterTools");
            test.applyFixture(PathFixture(test.pkgFolder));
            test.applyFixture(PathFixture(test.paramFolder));
        end

    end

    methods (Test)

        function allExternalNoEncodingMsg(test)
        % All-indirect tool: no parameter should have the encoding message.

            import prodserver.mcp.MCPConstants

            td = wrapAndDefine(test, "allIndirect");
            props = td.tools{1}.inputSchema.properties;
            names = fieldnames(props);
            for k = 1:numel(names)
                desc = strjoin(string(props.(names{k}).description), newline);
                test.verifyFalse( ...
                    contains(desc, MCPConstants.WireEncodingResourceURI), ...
                    sprintf("Parameter '%s' should not have encoding message", names{k}));
            end

            % Top-level tool description still has the required-reading instruction
            toolDesc = strjoin(string(td.tools{1}.description), newline);
            test.verifyTrue( ...
                contains(toolDesc, MCPConstants.WireEncodingResourceURI), ...
                "Tool description must reference wire-encoding resource");
        end

        function mixedExternalAndLiteral(test)
        % oneIndirectOutput: inline inputs get encoding msg, externalized output does not.

            import prodserver.mcp.MCPConstants

            td = wrapAndDefine(test, "oneIndirectOutput");
            props = td.tools{1}.inputSchema.properties;

            % yURL is the externalized output — should NOT have encoding msg
            test.verifyTrue(isfield(props,"yURL"), "yURL field expected");
            yDesc = strjoin(string(props.yURL.description), newline);
            test.verifyFalse( ...
                contains(yDesc, MCPConstants.WireEncodingResourceURI), ...
                "Externalized output yURL should not have encoding message");

            % Inline inputs (a, b, c, d) SHOULD have encoding msg
            for p = ["a","b","c","d"]
                desc = strjoin(string(props.(p).description), newline);
                test.verifyTrue( ...
                    contains(desc, MCPConstants.WireEncodingResourceURI), ...
                    sprintf("Inline input '%s' should have encoding message", p));
            end
        end

        function allLiteralHasEncodingMsg(test)
        % threeFour: all scalar, no externalization. All params get encoding msg.

            import prodserver.mcp.MCPConstants

            tool = "threeFour";
            td = prodserver.mcp.internal.defineForMCP(tool, tool);

            % Check inputs
            inProps = td.tools{1}.inputSchema.properties;
            inNames = fieldnames(inProps);
            for k = 1:numel(inNames)
                desc = strjoin(string(inProps.(inNames{k}).description), newline);
                test.verifyTrue( ...
                    contains(desc, MCPConstants.WireEncodingResourceURI), ...
                    sprintf("Input '%s' should have encoding message", inNames{k}));
            end

            % Check outputs
            outProps = td.tools{1}.outputSchema.properties;
            outNames = fieldnames(outProps);
            for k = 1:numel(outNames)
                desc = strjoin(string(outProps.(outNames{k}).description), newline);
                test.verifyTrue( ...
                    contains(desc, MCPConstants.WireEncodingResourceURI), ...
                    sprintf("Output '%s' should have encoding message", outNames{k}));
            end
        end

        function defsDescriptionClean(test)
        % $defs descriptions must not contain the encoding resource URI.

            import prodserver.mcp.MCPConstants

            td = wrapAndDefine(test, "oneIndirectOutput");
            defs = td.tools{1}.(MCPConstants.DefsField);

            % Check inputSchema defs (none expected for oneIndirectOutput)
            if isfield(defs, "inputSchema")
                checkDefsClean(test, defs.inputSchema);
            end

            % Check outputSchema defs
            if isfield(defs, "outputSchema")
                checkDefsClean(test, defs.outputSchema);
            end
        end

        function optionalGroupMsgWording(test)
        % Tool description uses new wording, not old MATLAB jargon.

            import prodserver.mcp.MCPConstants

            td = wrapAndDefine(test, "oneIndirectOutput");
            toolDesc = strjoin(string(td.tools{1}.description), newline);

            test.verifyFalse( ...
                contains(toolDesc, "name/value pair"), ...
                "Tool description should not use 'name/value pair' jargon");

            test.verifyTrue( ...
                contains(toolDesc, "output locations"), ...
                "Tool description should mention 'output locations'");
        end

        function externalizedOutputNoEncode(test)
        % Regression: externalized output must not say "encode".

            import prodserver.mcp.MCPConstants

            td = wrapAndDefine(test, "oneIndirectOutput");
            props = td.tools{1}.inputSchema.properties;

            yDesc = strjoin(string(props.yURL.description), newline);
            test.verifyFalse(contains(yDesc, "encode"), ...
                "Externalized output should not say 'encode'");
            test.verifyTrue( ...
                contains(yDesc, MCPConstants.ByReferencePrefix), ...
                "Externalized output should have by-reference prefix");
        end

    end

    methods (Access = private)

        function td = wrapAndDefine(test, fcn)
        % Generate wrapper and definition for a parameterTools function.

            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.applyFixture(PathFixture(tFolder.Folder));

            [wrapper, defs] = prodserver.mcp.internal.wrapForMCP( ...
                fcn, "", tFolder.Folder);
            [~, tool] = fileparts(wrapper);
            td = prodserver.mcp.internal.defineForMCP(fcn, tool, defs=defs);
        end

        function checkDefsClean(test, defsGroup)
        % Verify no $defs entry description contains the encoding URI.

            import prodserver.mcp.MCPConstants

            names = fieldnames(defsGroup);
            for k = 1:numel(names)
                entry = defsGroup.(names{k});
                if isfield(entry, "description")
                    desc = entry.description;
                    if iscell(desc)
                        desc = strjoin(string(desc), newline);
                    end
                    test.verifyFalse( ...
                        contains(desc, MCPConstants.WireEncodingResourceURI), ...
                        sprintf("$defs entry '%s' should not have encoding message", names{k}));
                end
            end
        end

    end
end
