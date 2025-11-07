classdef tMarshal < matlab.unittest.TestCase
% Test marshaling (serialize/deserialize)

    properties
        tempDir
    end

    methods (TestClassSetup)
        function initFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.tempDir = TemporaryFolderFixture(WithSuffix="sp a ce");
            testCase.applyFixture(testCase.tempDir);
        end

    end


    methods (Test)

        function tCSV(testCase)

            tfolder = testCase.tempDir.Folder;
            expected = 1:10;
            csvFile = fullfile(tfolder,"data.csv");
            writematrix(expected,csvFile);

            % URLs use forward-slash only.
            url = "file:" + csvFile;
            url = replace(url,filesep,"/");

            marshaller = prodserver.mcp.io.MarshallURI();
            % Always returns a cell array
            actual = deserialize(marshaller, url);
            testCase.verifyEqual(actual{1},expected);

        end


    end

end
