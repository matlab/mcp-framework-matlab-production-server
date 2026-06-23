classdef tAdditionalFiles < matlab.unittest.TestCase 

% Copyright 2026 The MathWorks, Inc.

    properties
        toolFolder
    end

    methods (TestClassSetup)

        function registerPackage(test)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end

        function initPath(test)
            % Put the toyTools folder on the path.
            import matlab.unittest.fixtures.PathFixture
            test.toolFolder = fullfile(fileparts(mfilename("fullpath")),...
                "..", "..", "tools","toyTools");
            test.applyFixture(PathFixture(test.toolFolder));
        end
    end

    methods

        function validateFileCapture(test,archive,files)

            [~,listOutput] = system("unzip -l """ + archive + """");
            % Extract file entries beginning with "fsroot"
            fileList = regexp(listOutput, 'fsroot[\S ]*\n', 'match');

            for n = 1:numel(files)
                found = nnz(contains(fileList, files(n)));
                test.verifyEqual(found,1,...
                    "Wrong number of matches ("+string(found)+") for " + files(n));
            end

        end
    end

    methods(Test)

        function oneFile(test)
        % Add a single file

            % Temporary folder to contain extra files
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            fileFolder = tFolder.Folder;

            % Create a data file in the file folder
            x = 17;
            seventeen = "seventeen";
            seventeenFcn = "magic17";
            seventeenData = seventeen + ".mat";
            seventeenPath = fullfile(fileFolder,seventeenData);
            save(seventeenPath,"x");
        
            ctf = prodserver.mcp.build(seventeenFcn,folder=fileFolder,...
                files=seventeenPath);
            validateFileCapture(test,ctf,seventeenData);
        end

        function twoFile(test)
        % Two different files from different directories.

            % Two folders for the data files
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            fileFolder = tFolder.Folder;

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            secondFolder = tFolder.Folder;

            nameOne = "firstFile.mat";
            one = fullfile(fileFolder,nameOne);
            contentsOne = 81;
            save(one,"contentsOne");

            nameTwo = "secondFile.mat";
            two = fullfile(secondFolder,nameTwo);
            contentsTwo = 64;
            save(two,"contentsTwo");

            % Row vector of extra files
            ctf = prodserver.mcp.build("toySummary", folder=fileFolder, ...
                files=[one,two]);
            validateFileCapture(test,ctf,[nameOne,nameTwo]);

            % Column vector of extra files
            ctf = prodserver.mcp.build("toySummary", folder=secondFolder, ...
                files=[one,two]);
            validateFileCapture(test,ctf,[nameOne,nameTwo]);
        end

        function redFile(test)
        % Files that don't exist

            import matlab.unittest.fixtures.TemporaryFolderFixture

            % One file that exists and one that doesn't
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            fileFolder = tFolder.Folder;

            nameOne = "firstFile.mat";
            one = fullfile(fileFolder,nameOne);
            contentsOne = 81;
            save(one,"contentsOne");

            nope = "nope.mat";
            nopeFolder = "/i/do/not/think/so";
            nopePath = fullfile(nopeFolder,nope);

            % Expect an error containing the path to the non-existent file
            try
                ctf = prodserver.mcp.build("toySummary", folder=fileFolder, ...
                    files=[one,nopePath]);
                test.verifyFail("Non-existent file failed to trigger error");
            catch me
                % Gallingly, me.identifier is a char.
                test.verifyEqual(me.identifier,'prodserver:mcp:AdditionalFileNotFound');
                test.verifyTrue(contains(me.message,nopePath));
                test.verifyEqual(exist("ctf","var"),0,...
                    "CTF created, despite missing file");
            end

            % And the same when the missing file is the first one
            try
                ctf = prodserver.mcp.build("toySummary", folder=fileFolder, ...
                    files=[nopePath,one]);
                test.verifyFail("Non-existent file failed to trigger error");
            catch me
                test.verifyEqual(me.identifier,'prodserver:mcp:AdditionalFileNotFound');
                test.verifyTrue(contains(me.message,nopePath));
                test.verifyEqual(exist("ctf","var"),0,...
                    "CTF created, despite missing file");
            end

        end

        function blueFile(test)
        % Lots of files (seventeen of them).

            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            fileFolder = tFolder.Folder;
    
            N = 17;
            baseName = "dataFile";
            dataFile = strings(1,N);
            dataName = dataFile;
            for k = 1:N
                dataName(k) = baseName+string(k)+".mat";
                dataFile(k) = fullfile(fileFolder,dataName(k));
                content = k;
                save(dataFile(k),"content");
            end

            % Files may be row or column vector
            ctf = prodserver.mcp.build("toySummary", folder=fileFolder, ...
                files=dataFile);
            validateFileCapture(test,ctf,dataName);

            dataFile = dataFile';
            ctf = prodserver.mcp.build("toySummary", folder=fileFolder, ...
                files=dataFile);
            validateFileCapture(test,ctf,dataName);

            % Add another file
            x = 17;
            seventeen = "seventeen";
            seventeenData = seventeen + ".mat";
            seventeenPath = fullfile(fileFolder,seventeenData);
            save(seventeenPath,"x");

            % Multiple tools with many files
            dataFile = [dataFile;seventeenPath];
            dataName = [dataName,seventeenData];
            ctf = prodserver.mcp.build(["toySummary", "magic17", ...
                "toyScalarOne"], folder=fileFolder, files=dataFile);
            validateFileCapture(test,ctf,dataName);

            % And with dataFile as a row vector
            dataFile = dataFile';
            ctf = prodserver.mcp.build(["toySummary", "magic17", ...
                "toyScalarOne"], folder=fileFolder, files=dataFile);
            validateFileCapture(test,ctf,dataName);

        end

    end
end
