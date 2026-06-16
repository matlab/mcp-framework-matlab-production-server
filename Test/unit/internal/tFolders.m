classdef tFolders < matlab.unittest.TestCase

    methods(Test)
        function bin(testCase)
            binFolder = prodserver.mcp.internal.binFolder;
            bf = mfilename("fullpath");
            bf = erase(bf,fullfile("Test","unit","internal",mfilename));
            bf = fullfile(bf,"bin",computer("arch"));
            testCase.verifyEqual(binFolder,bf);

            yamlFolder = "yaml2json";
            binFolder = prodserver.mcp.internal.binFolder(yamlFolder);
            testCase.verifyEqual(binFolder,fullfile(bf,yamlFolder));
        end

        function package(testCase)
            [pkg, bin] = prodserver.mcp.internal.packageFolder;

            pf = string(mfilename("fullpath"));
            pf = erase(pf,fullfile("Test","unit","internal",mfilename));
            bf = fullfile(pf,"bin",computer("arch"));
            testCase.verifyEqual(pkg,pf);
            testCase.verifyEqual(bin,bf);
            testCase.verifyEqual(prodserver.mcp.internal.binFolder,bf);
        end

    end
end