classdef tArchiveUUID < matlab.unittest.TestCase
% Test prodserver.mcp.internal.archiveUUID: the build's UUID, from a .ctf
% file or the running archive.

% Copyright 2026 The MathWorks, Inc.

    properties
        folder
    end

    methods (TestMethodSetup)
        function makeFolder(test)
            test.folder = string(test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
        end
    end

    methods (Access = private)

        function ctf = archive(test, manifest)
        % A .ctf file -- a zip file -- with .META/manifest.xml MANIFEST and
        % something else.
            root = fullfile(test.folder, "unpacked");
            mkdir(fullfile(root, ".META"));
            writelines(manifest, fullfile(root, ".META", "manifest.xml"));
            writelines("x", fullfile(root, "other.txt"));
            zip(fullfile(test.folder, "a.zip"), [".META", "other.txt"], root);
            ctf = fullfile(test.folder, "a.ctf");
            movefile(fullfile(test.folder, "a.zip"), ctf);
        end

    end

    methods (Test)

        function fromArchiveFile(test)
            ctf = test.archive("<manifest container_uuid="""" " + ...
                "uuid=""a_1234""><directory id=""d""/></manifest>");
            test.verifyEqual(prodserver.mcp.internal.archiveUUID(ctf), "a_1234");
        end

        function notContainerUUID(test)
            % container_uuid comes first, and ends in uuid="..." too.
            ctf = test.archive("<?xml version=""1.0""?><manifest " + ...
                "container_uuid=""c_0"" uuid=""a_9""></manifest>");
            test.verifyEqual(prodserver.mcp.internal.archiveUUID(ctf), "a_9");
        end

        function manifestWithoutUUIDHasNone(test)
            ctf = test.archive("<manifest container_uuid=""""></manifest>");
            test.verifyEqual(prodserver.mcp.internal.archiveUUID(ctf), "");
        end

        function notAZipFileHasNone(test)
            % Like the fake archives deploy's tests upload.
            ctf = fullfile(test.folder, "fake.ctf");
            writelines("accept", ctf);
            test.verifyEqual(prodserver.mcp.internal.archiveUUID(ctf), "");
        end

        function zipWithoutManifestHasNone(test)
            writelines("x", fullfile(test.folder, "other.txt"));
            zip(fullfile(test.folder, "b.zip"), "other.txt", test.folder);
            ctf = fullfile(test.folder, "b.ctf");
            movefile(fullfile(test.folder, "b.zip"), ctf);
            test.verifyEqual(prodserver.mcp.internal.archiveUUID(ctf), "");
        end

        function missingFileHasNone(test)
            test.verifyEqual(prodserver.mcp.internal.archiveUUID( ...
                fullfile(test.folder, "absent.ctf")), "");
        end

        function notDeployedHasNone(test)
            % Outside the MATLAB Runtime there is no AppComponentUUID. The
            % deployed value is checked by tDeployOverwrite.
            test.verifyEqual(prodserver.mcp.internal.archiveUUID(), "");
        end

    end

end
