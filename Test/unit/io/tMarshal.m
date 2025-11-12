classdef tMarshal < matlab.unittest.TestCase
% Test marshaling (serialize/deserialize)

    properties
        tempDir
        marshaller
    end

    methods (TestClassSetup)
        function initFolder(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            test.tempDir = TemporaryFolderFixture(WithSuffix="sp a ce");
            test.applyFixture(test.tempDir);

            test.marshaller = prodserver.mcp.io.MarshallURI();

        end
    end

    methods (Test)

        function tCSV(test)

            tfolder = test.tempDir.Folder;

            % 
            % deserialize  
            % 

            original = 1:10;
            csvFile = fullfile(tfolder,"readThis.csv");
            writematrix(original,csvFile);

            % URLs use forward-slash only.
            url = "file:" + csvFile;
            url = replace(url,filesep,"/");

            % Always returns a cell array
            actual = deserialize(test.marshaller, url);
            test.verifyEqual(actual{1},original,"deserialize");

            %
            % serialize
            %

            % URLs use forward-slash only.
            csvFile = fullfile(tfolder,"wroteThat.csv");
            url = "file:" + csvFile;
            url = replace(url,filesep,"/");

            serialize(test.marshaller,url,{original});

            actual = readmatrix(csvFile);
            test.verifyEqual(actual,original,"serialize");

            % 
            % Round trip
            %

            original = [ 64, 82, 86, 93, 94, 99, 2, 3, 17, 20 ];

            % URLs use forward-slash only.
            csvFile = fullfile(tfolder,"wroteThenRead.csv");
            url = "file:" + csvFile;
            url = replace(url,filesep,"/");

            serialize(test.marshaller,url,{original});

            actual = deserialize(test.marshaller, url);
            test.verifyEqual(actual{1},original,"serialize");

        end

        function tMAT(test)

            import prodserver.mcp.internal.Constants
            tfolder = test.tempDir.Folder;

            % 
            % deserialize  
            % 

            original = 1:10;
            dataFile = fullfile(tfolder,"readThis.mat");
            save(dataFile,"original");

            % URLs use forward-slash only.
            url = "file:" + dataFile;
            url = replace(url,filesep,"/");

            % Always returns a cell array
            actual = deserialize(test.marshaller, url);
            test.verifyEqual(actual{1},original,"deserialize");

            %
            % serialize
            %

            % URLs use forward-slash only.
            dataFile = fullfile(tfolder,"wroteThat.mat");
            url = "file:" + dataFile;
            url = replace(url,filesep,"/");

            serialize(test.marshaller,url,{original});

            actual = load(dataFile);
            actual = actual.(Constants.DefaultPersistVar);
            test.verifyEqual(actual,original,"serialize");

            % 
            % Round trip
            %

            original = [ 64, 82, 86, 93, 94, 99, 2, 3, 17, 20 ];

            % URLs use forward-slash only.
            dataFile = fullfile(tfolder,"wroteThenRead.csv");
            url = "file:" + dataFile;
            url = replace(url,filesep,"/");

            serialize(test.marshaller,url,{original});

            actual = deserialize(test.marshaller, url);
            test.verifyEqual(actual{1},original,"serialize");

        end


    end

end
