classdef tMarshal < matlab.unittest.TestCase
% Test marshaling (serialize/deserialize)

% Copyright 2025-2026 The MathWorks, Inc.

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

        function tJSON(test)

            tfolder = test.tempDir.Folder;

            %
            % deserialize
            %

            original = struct('x', 1, 'y', [2 3 4]);
            jsonFile = fullfile(tfolder,"readThis.json");
            prodserver.mcp.io.saveJSON(jsonFile, original);

            % URLs use forward-slash only.
            url = "file:" + jsonFile;
            url = replace(url,filesep,"/");

            % Always returns a cell array
            actual = deserialize(test.marshaller, url);
            test.verifyTrue(isequaln(actual{1},original),"deserialize");

            %
            % serialize
            %

            % URLs use forward-slash only.
            jsonFile = fullfile(tfolder,"wroteThat.json");
            url = "file:" + jsonFile;
            url = replace(url,filesep,"/");

            serialize(test.marshaller,url,{original});

            actual = prodserver.mcp.io.loadJSON(jsonFile);
            test.verifyTrue(isequaln(actual,original),"serialize");

            %
            % Round trip
            %

            original = struct('name', 'test', 'values', magic(3));

            % URLs use forward-slash only.
            jsonFile = fullfile(tfolder,"wroteThenRead.json");
            url = "file:" + jsonFile;
            url = replace(url,filesep,"/");

            serialize(test.marshaller,url,{original});

            actual = deserialize(test.marshaller, url);
            test.verifyTrue(isequaln(actual{1},original),"round trip");

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

        function tSerializeParsedURI(test)
            % serialize returns the location for a parsed (struct)
            % location, as it does for text.
            import prodserver.mcp.io.parseURI

            matFile = fullfile(test.tempDir.Folder,"parsed.mat");
            url = replace("file:" + matFile,filesep,"/");

            update = serialize(test.marshaller,parseURI(url),{5});
            test.verifyEqual(update,url,"file: location");
            test.verifyEqual(exist(matFile,"file"),2,"file written");
            test.verifyEqual(deserialize(test.marshaller,url),{5}, ...
                "file contents");

            % json: carries the value in the query, so serialize returns
            % what the writer returns -- the same for either form.
            json = "json:x?0";
            test.verifyEqual(serialize(test.marshaller,parseURI(json),{42}), ...
                serialize(test.marshaller,json,{42}),"json: location");
        end

        function tDefaultSchemeFromFile(test)
            % A configuration file keeps the default scheme.
            cfgFile = fullfile(test.tempDir.Folder,"marshall.yaml");
            prodserver.mcp.io.MarshallURI.ExportConfiguration( ...
                test.marshaller.config,cfgFile,"json");

            mu = prodserver.mcp.io.MarshallURI(Config=cfgFile);
            % The file's value is char (from jsondecode).
            test.verifyEqual(string(mu.defaultScheme),"json");
        end

    end

end
