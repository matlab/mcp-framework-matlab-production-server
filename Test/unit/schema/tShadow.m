classdef tShadow < matlab.unittest.TestCase
%tShadow Unit tests for prodserver.mcp.internal.generateShadow.

% Copyright 2026 The MathWorks, Inc.

    properties
        toolsFolder
    end

    methods(TestClassSetup)
        function requireToyTools(test)
            rtt = test.applyFixture(...
                prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;
        end
    end

    methods(Test)

        function createsFolder(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            test.verifyTrue(isfolder(shadowDir));
        end

        function createsFunctionFile(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            test.verifyTrue(isfile(fullfile(shadowDir, "toyToolOne.m")));
        end

        function codeContainsRmpath(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyToolOne.m"));
            test.verifyTrue(contains(code, "rmpath("));
        end

        function codeContainsAddpathTwice(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyToolOne.m"));
            matches = count(code, "addpath(");
            test.verifyEqual(matches, 2, ...
                "Expected addpath in both try and catch blocks");
        end

        function codeContainsObsRecord(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyToolOne.m"));
            matches = count(code, "obs.record(");
            test.verifyEqual(matches, 2, ...
                "Expected obs.record for input and output");
        end

        function positionalCountSimple(test)
            % toyToolOne has 2 required positional inputs
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyToolOne.m"));
            % The input record call should show nPositional=2
            test.verifyTrue(contains(code, ...
                'obs.record("toyToolOne", "input", ["a","b"], varargin, 2)'));
        end

        function nvpExcluded(test)
            % toyScalarNVOptions has 1 positional + 4 NVP
            shadowDir = prodserver.mcp.internal.generateShadow("toyScalarNVOptions");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyScalarNVOptions.m"));
            % nPositional should be 1 (only 'year')
            test.verifyTrue(contains(code, ...
                'obs.record("toyScalarNVOptions", "input", "year", varargin, 1)'));
        end

        function outputNamesCorrect(test)
            % toyToolOne has 3 outputs: x, y, z
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyToolOne.m"));
            test.verifyTrue(contains(code, ...
                'obs.record("toyToolOne", "output", ["x","y","z"], varargout, 3)'));
        end

        function multipleFunctions(test)
            shadowDir = prodserver.mcp.internal.generateShadow(...
                ["toyToolOne","toyScalarTwo"]);
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            test.verifyTrue(isfile(fullfile(shadowDir, "toyToolOne.m")));
            test.verifyTrue(isfile(fullfile(shadowDir, "toyScalarTwo.m")));
        end

        function cleanupRemovable(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            test.verifyTrue(isfolder(shadowDir));
            rmdir(shadowDir, 's');
            test.verifyFalse(isfolder(shadowDir));
        end

        function usesVararginVarargout(test)
            shadowDir = prodserver.mcp.internal.generateShadow("toyToolOne");
            cleanup = onCleanup(@() rmdir(shadowDir,'s'));
            code = fileread(fullfile(shadowDir, "toyToolOne.m"));
            test.verifyTrue(contains(code, "function [varargout] = toyToolOne(varargin)"));
        end

    end
end
