classdef tFile < matlab.unittest.TestCase
% Test io.File marshaling (serialize/deserialize)

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
        function url2Path(test)

            f = "/high/speed/storage/data.csv";

            % Only run this test on Windows platforms, because no others
            % will produce drive-letter-prefixed paths.
            if ispc
                % Absolute path, because of drive letter.
                % file://C:/high/speed/storage/data.csv
                u = "file:/" + "/C:" + f;
                p = prodserver.mcp.io.uri.File.FileURI2Path(u);
                test.verifyEqual(p,"C:"+f);
            end

            % UNC path -- allowed on all platforms.
            % file:////high/speed/storage/data.csv
            u = "file:///"+f;
            p = prodserver.mcp.io.uri.File.FileURI2Path(u);
            test.verifyEqual(p,"/"+f);

            % Absolute Unix-style path
            u = "file:"+f;
            p = prodserver.mcp.io.uri.File.FileURI2Path(u);
            test.verifyEqual(p,f);

            if ispc
                % file:C:/high/speed/storage/data.csv
                u = "file:" + "C:" + f;
                p = prodserver.mcp.io.uri.File.FileURI2Path(u);
                test.verifyEqual(p,"C:"+f);
            end

            % Absolute path
            % file:///high/speed/storage/data.csv
            u = "file://"+f;
            p = prodserver.mcp.io.uri.File.FileURI2Path(u);
            test.verifyEqual(p,f);

            % Relative path on host "high". Probably unexpected, but the
            % standard is the standard...
            % file://high/speed/storage/data.csv
            u = "file:/"+f;
            p = prodserver.mcp.io.uri.File.FileURI2Path(u);
            test.verifyEqual(p,extractAfter(f,textBoundary("start")+"/high"));
            
        end
    end
end