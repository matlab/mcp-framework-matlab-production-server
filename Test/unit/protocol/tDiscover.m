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

    end

end
