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

        function periodicNoise(test)
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

            % Run the original and output the data into the deployment
            % folder.
            frequency = 60;
            noisyFile = fullfile(csFolder,"openloopVoltage.csv");
            noisy = readmatrix(noisyFile);
            clean = cleanSignal(noisy, frequency);

            % Run the MCP tool and output the data into the deployment
            % folder.

            noisyURL = "file:" + noisyFile;
            cleanFile = fullfile(tempFolder.Folder,"cleanLoopVoltage.csv");
            cleanURL = "file:" + cleanFile;
            cleanSignalMCP(noisyURL,frequency,cleanURL);
            test.verifyEqual(exist(cleanFile,"file"),2,cleanFile);

            % The output data must be identical, within tolerance --
            % writing the data to CSV files entails some loss of precision.
            mcpClean = readmatrix(cleanFile);
            test.verifyEqual(clean,mcpClean,"Clean signal",AbsTol=1e-12);
        end

        function somePrimes(test)
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