classdef tLoadmatrix < matlab.unittest.TestCase
% Test prodserver.mcp.io.loadmatrix (load a named variable from a MAT-file and
% return its value).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tLoadsNamedVariable(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import prodserver.mcp.io.loadmatrix
            f = test.applyFixture(TemporaryFolderFixture);
            matFile = fullfile(f.Folder, "data.mat");
            expected = magic(3);
            other = 7;
            save(matFile, "expected", "other");

            value = loadmatrix("expected", char(matFile));
            test.verifyEqual(value, magic(3));
        end

    end

end
