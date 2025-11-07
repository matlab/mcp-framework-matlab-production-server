classdef texamples < matlab.unittest.TestCase

    properties
        exampleFolder
    end

    methods(TestClassSetup)
        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.exampleFolder = fullfile(testFolder,"..","..","..","Examples");
        end
    end

    methods(Test)

        function cleanSignal(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempFolder = TemporaryFolderFixture;
            applyFixture(test,tempFolder);
            csFolder = fullfile(test.exampleFolder,"Periodic Noise");
            applyFixture(test,PathFixture(csFolder));

            ctf = prodserver.mcp.build("cleanSignal", ...
                folder=tempFolder.Folder,...
                wrapper=fullfile(csFolder,"cleanSignalMCP.m"), ...
                definition=fullfile(csFolder,"cleanSignalMCPTool.json"));
            
            test.verifyTrue(startsWith(ctf,tempFolder.Folder));

        end

        function primeSequence(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempFolder = TemporaryFolderFixture;
            applyFixture(test,tempFolder);
            csFolder = fullfile(test.exampleFolder,"Primes");
            applyFixture(test,PathFixture(csFolder));

            ctf = prodserver.mcp.build("primeSequence", ...
                folder=tempFolder.Folder, wrapper="None");

            test.verifyTrue(startsWith(ctf,tempFolder.Folder));

        end

        function earthquake(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            tempFolder = TemporaryFolderFixture;
            applyFixture(test,tempFolder);
            csFolder = fullfile(test.exampleFolder,"Earthquake");
            applyFixture(test,PathFixture(csFolder));

            ctf = prodserver.mcp.build("plotTrajectories", ...
                folder=tempFolder.Folder,...
                wrapper=fullfile(csFolder,"plotTrajectoriesMCP.m"));

            test.verifyTrue(startsWith(ctf,tempFolder.Folder));
        end
    end

end