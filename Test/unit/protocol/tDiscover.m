classdef tDiscover < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.discover.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function addPath(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder, "..", "..", "..");
            test.applyFixture(PathFixture(pkgFolder));
        end
    end

    methods (Test)

        function tReturnsSupportedVersions(test)
            jrpc = struct('jsonrpc', '2.0', 'id', 1, ...
                'method', 'server/discover');
            [result, httpCode, ~, ~] = ...
                prodserver.mcp.protocol.v20260728.discover(jrpc);
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(result.id, 1);
            versions = result.result.supportedVersions;
            test.verifyTrue(ismember("2025-06-18", versions));
            test.verifyTrue(ismember("2026-07-28", versions));
        end

        function tReturnsCapabilities(test)
            jrpc = struct('jsonrpc', '2.0', 'id', 2, ...
                'method', 'server/discover');
            [result, ~, ~, ~] = ...
                prodserver.mcp.protocol.v20260728.discover(jrpc);
            test.verifyTrue(isfield(result.result, 'capabilities'));
            caps = result.result.capabilities;
            fn = fieldnames(caps);
            for i = 1:numel(fn)
                test.verifyTrue(isfield(caps.(fn{i}), 'listChanged'));
                test.verifyFalse(caps.(fn{i}).listChanged);
            end
        end

        function tReturnsInstructions(test)
            jrpc = struct('jsonrpc', '2.0', 'id', 3, ...
                'method', 'server/discover');
            [result, ~, ~, ~] = ...
                prodserver.mcp.protocol.v20260728.discover(jrpc);
            test.verifyTrue(isfield(result.result, 'instructions'));
            test.verifyClass(result.result.instructions, 'string');
            test.verifyGreaterThan(strlength(result.result.instructions), 0);
        end

        function tAdvertisesUIExtensionWithApp(test)
            % An archive built with an MCP App advertises the UI extension
            % under 2026-07-28 too: both revisions share capabilities().
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.applyFixture(PathFixture(tFolder.Folder));
            def.(MCPConstants.AppResourceVariable) = true;
            save(fullfile(tFolder.Folder, MCPConstants.DefinitionFile), ...
                "-struct", "def");
            % The definitions are cached; clear them now and afterwards, so
            % the app flag reaches only this test.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));

            jrpc = struct('jsonrpc', '2.0', 'id', 4, ...
                'method', 'server/discover');
            [result, ~, ~, ~] = ...
                prodserver.mcp.protocol.v20260728.discover(jrpc);
            caps = result.result.capabilities;
            test.verifyTrue(isfield(caps, 'extensions') && ...
                isfield(caps.extensions, MCPConstants.UIExtension_Field), ...
                "server/discover should advertise " + MCPConstants.UIExtension_JSON);
        end

    end

end
