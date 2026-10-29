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

        function existEmptyAuthority(test)
            % file:///<path> (and file:///C:/<path> on Windows) names an
            % existing file.
            [yes, no] = fileURIs(test, "file:///");
            fs = prodserver.mcp.io.uri.File();

            test.verifyTrue(conforms(fs,yes),"conforms");
            test.verifyTrue(exist(fs,yes),"exist File");
            test.verifyFalse(exist(fs,no),"exist File, missing");
            test.verifyEqual(exist(test.marshaller,[yes no]),[true false], ...
                "exist MarshallURI");
        end

        function existArray(test)
            % conforms and exist take arrays, in any order, including
            % URIs of other schemes.
            fs = prodserver.mcp.io.uri.File();
            for prefix = ["file:", "file:///"]
                [yes, no] = fileURIs(test, prefix);
                test.verifyEqual(conforms(fs,[yes "json:x?1"]),[true false], ...
                    prefix + " conforms");
                test.verifyEqual(exist(fs,[yes no]),[true false], ...
                    prefix + " exist");
                test.verifyEqual(exist(fs,[no yes]),[false true], ...
                    prefix + " exist, reversed");
                test.verifyEqual(exist(fs,[yes "json:x?1" no]), ...
                    [true false false], prefix + " exist, mixed schemes");
            end
        end

        function charURIs(test)
            % A char URI is one URI, not one per character, for File and
            % for MarshallURI.
            fs = prodserver.mcp.io.uri.File();
            [yes, no] = fileURIs(test, "file:///");
            yes = char(yes);
            no = char(no);
            test.verifyEqual(conforms(fs,yes),true,"conforms");
            test.verifyEqual(conforms(fs,no),true,"conforms, missing");
            test.verifyEqual(conforms(fs,'json:x?1'),false,"other scheme");
            test.verifyEqual(conforms(fs,{yes,'json:x?1'}),[true false], ...
                "conforms cellstr");
            test.verifyEqual(exist(fs,yes),true,"exist");
            test.verifyEqual(exist(fs,no),false,"exist, missing");
            test.verifyEqual(exist(fs,{yes,no}),[true false], ...
                "exist cellstr");

            test.verifyEqual(conforms(test.marshaller,yes),true, ...
                "MarshallURI conforms");
            test.verifyEqual(exist(test.marshaller,yes),true, ...
                "MarshallURI exist");
            test.verifyEqual(exist(test.marshaller,no),false, ...
                "MarshallURI exist, missing");
            test.verifyEqual(exist(test.marshaller,{yes,no}),[true false], ...
                "MarshallURI exist cellstr");
        end

        function clearReportsUnremovableFolder(test)
            % clear raises SessionDataPersists when it empties a subfolder of
            % the session root but can't remove it. Windows won't remove a
            % process's current folder; elsewhere a folder can't be removed
            % from a read-only parent.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.CurrentFolderFixture

            root = test.applyFixture(TemporaryFolderFixture).Folder;
            uuid = matlab.lang.internal.uuid();
            sid = "SID:MathWorks-Production-MCP-Server:tFile:" + uuid;
            fs = prodserver.mcp.io.uri.File(dictionary( ...
                [prodserver.mcp.io.Scheme.sessionIdToken, ...
                 prodserver.mcp.io.uri.File.persistRootToken], ...
                [sid, string(root)]));

            % activate attaches to the session root, which must exist.
            parent = fullfile(root, uuid, "a");
            stuck = fullfile(parent, "b");
            mkdir(stuck);
            fs = activate(fs);

            if ispc
                test.applyFixture(CurrentFolderFixture(stuck));
            else
                fileattrib(parent, "-w");
                test.addTeardown(@()fileattrib(parent, "+w"));
                test.assumeFalse(mkdir(fullfile(parent, "probe")), ...
                    "A read-only folder is still writable (running as root?)");
            end

            test.verifyError(@()clear(fs), ...
                "prodserver:mcp:SessionDataPersists");
        end

        function path2FileURIRoundTrip(test)
            % Characters a URI reserves, a literal percent-encoding and
            % non-ASCII names must all survive the trip to a URI and back,
            % and the URI must read. (? is not a legal Windows file name
            % character; see path2FileURIEncodesQueryAndFragment.)
            names = ["my data", "50% off", "a#b", "[x]", "a@b", ...
                "a+b;c", "%41", "été", "日本", "emoji😀"];
            fs = prodserver.mcp.io.uri.File();
            for nm = names
                d = fullfile(test.tempDir.Folder, nm);
                mkdir(d);
                f = fullfile(d, "v.json");
                writelines('{"v":7}', f);

                u = prodserver.mcp.io.uri.File.Path2FileURI(f);
                test.verifyTrue(startsWith(u, "file:///"), nm);

                p = prodserver.mcp.io.uri.File.FileURI2Path(u);
                test.verifyEqual(p, replace(string(f), filesep, "/"), nm);

                pu = prodserver.mcp.io.parseURI(u);
                test.verifyEqual(strlength(strjoin(["" string(pu.query)], "")), 0, nm);
                test.verifyTrue(exist(fs, u), nm);

                v = deserialize(test.marshaller, u);
                test.verifyEqual(v{1}.v, 7, nm);
            end
        end

        function path2FileURIForms(test)
            import matlab.unittest.fixtures.CurrentFolderFixture
            test.applyFixture(CurrentFolderFixture(test.tempDir.Folder));
            here = replace(string(pwd), filesep, "/");
            P2U = @prodserver.mcp.io.uri.File.Path2FileURI;
            U2P = @prodserver.mcp.io.uri.File.FileURI2Path;

            % A relative path is made absolute against the current folder.
            test.verifyEqual(U2P(P2U("sub/x.json")), here + "/sub/x.json");

            if ispc
                test.verifyEqual(P2U("C:\a b\x.json"), "file:///C:/a%20b/x.json");
                test.verifyEqual(P2U("C:/a/x.json"), "file:///C:/a/x.json");
                test.verifyEqual(U2P(P2U("sub\x.json")), here + "/sub/x.json");
                % Root of the current drive.
                test.verifyEqual(P2U("\x.json"), ...
                    "file:///" + extractBefore(here, 3) + "/x.json");
                % UNC: empty authority, path //server/share.
                u = P2U("\\server\share\x.json");
                test.verifyEqual(u, "file:////server/share/x.json");
                test.verifyEqual(U2P(u), "//server/share/x.json");
                % Drive-relative: relative to a folder MATLAB doesn't know.
                test.verifyError(@() P2U("C:rel\x.json"), "prodserver:mcp:BadFilePath");
                test.verifyError(@() P2U("C:"), "prodserver:mcp:BadFilePath");
            else
                test.verifyEqual(P2U("/a b/x.json"), "file:///a%20b/x.json");
                % \ is an ordinary file name character here.
                test.verifyEqual(P2U("/a\b.json"), "file:///a%5Cb.json");
            end

            % Arrays keep their shape.
            u = P2U(["a.json"; "b c.json"]);
            test.verifySize(u, [2 1]);
        end

        function path2FileURIUNCCurrentFolder(test)
            % The root of a UNC current folder is its share, not //.
            import matlab.unittest.fixtures.CurrentFolderFixture
            test.assumeTrue(ispc, "UNC paths are Windows paths.");
            local = replace(string(test.tempDir.Folder), "/", "\");
            unc = "\\localhost\" + extractBefore(local, 2) + "$" + ...
                extractAfter(local, 2);
            test.assumeTrue(isfolder(unc), "No administrative share " + unc);
            test.applyFixture(CurrentFolderFixture(unc));
            share = "//localhost/" + extractBefore(local, 2) + "$";
            % Windows may report the share in another case (c$).
            u = prodserver.mcp.io.uri.File.Path2FileURI("\x.json");
            test.verifyEqual(lower(prodserver.mcp.io.uri.File.FileURI2Path(u)), ...
                lower(share + "/x.json"));
            u = prodserver.mcp.io.uri.File.Path2FileURI("x.json");
            test.verifyEqual(lower(prodserver.mcp.io.uri.File.FileURI2Path(u)), ...
                lower(replace(unc, "\", "/") + "/x.json"));
        end

        function fileURIRefusesEscapes(test)
            % A client's URI can't climb out of the folder it names.
            U2P = @prodserver.mcp.io.uri.File.FileURI2Path;
            for u = ["file:///tmp/a/../../etc/passwd", ...
                    "file:///tmp/a%2F..%2F..%2Fetc/passwd", "file:///tmp/a%2fb"]
                test.verifyError(@() U2P(u), "prodserver:mcp:BadFilePath", u);
            end
            if ispc
                test.verifyError(@() U2P("file:///C:/a%5C..%5Cb"), ...
                    "prodserver:mcp:BadFilePath");
            else
                % \ is an ordinary file name character here.
                test.verifyEqual(U2P("file:///a%5Cb.json"), "/a\b.json");
            end
            % A dot segment in a local path is resolved, not refused.
            P2U = @prodserver.mcp.io.uri.File.Path2FileURI;
            here = replace(string(pwd), filesep, "/");
            test.verifyEqual(U2P(P2U("sub/../x.json")), here + "/x.json");
            test.verifyEqual(U2P(P2U("./x.json")), here + "/x.json");
        end

        function dotSegments(test)
            R = @prodserver.mcp.io.removeDotSegments;
            test.verifyEqual(R("/a/b/../c/./d"), "/a/c/d");
            test.verifyEqual(R("/a/../../b"), "/b", "never above the root");
            test.verifyEqual(R("C:/a/.."), "C:/");
            test.verifyEqual(R("//server/share/a/../../x"), "//server/share/x");
            test.verifyEqual(R(["a/../b" "./x" "a/../../b" "."]), ...
                ["b" "x" "../b" "."], "relative");
        end

        function path2FileURILongPathPrefix(test)
            test.assumeTrue(ispc, "The long-path prefix is a Windows prefix.");
            P2U = @prodserver.mcp.io.uri.File.Path2FileURI;
            test.verifyEqual(P2U("\\?\C:\x.txt"), "file:///C:/x.txt");
            test.verifyEqual(P2U("\\?\UNC\server\share\x.txt"), ...
                "file:////server/share/x.txt");
        end

        function path2FileURIEncodesQueryAndFragment(test)
            if ispc
                f = "C:\a?b#c.json";
            else
                f = "/a?b#c.json";
            end
            u = prodserver.mcp.io.uri.File.Path2FileURI(f);
            test.verifyTrue(contains(u, "a%3Fb%23c.json"));
            pu = prodserver.mcp.io.parseURI(u);
            test.verifyEqual(strlength(strjoin(["" string(pu.query)], "")), 0);
            test.verifyEqual(prodserver.mcp.io.uri.File.FileURI2Path(u), ...
                replace(f, "\", "/"));
        end

        function path2FileURIEmptyErrors(test)
            test.verifyError(@()prodserver.mcp.io.uri.File.Path2FileURI(""), ...
                "prodserver:mcp:BadFilePath");
        end

        function fileURI2PathDecodesOnce(test)
            % %25 is a literal %, so %2541 is the three characters %41.
            if ispc
                u = "file:///C:/a%2541.json";
                expected = "C:/a%41.json";
            else
                u = "file:///a%2541.json";
                expected = "/a%41.json";
            end
            test.verifyEqual(prodserver.mcp.io.uri.File.FileURI2Path(u), ...
                expected);
        end
    end
end

function [yes, no] = fileURIs(test, prefix)
% URIs of an existing file and a missing one in the test's temporary
% folder. prefix is file: or file:///. On Windows the path begins with a
% drive letter; elsewhere with /, which file:/// already supplies. The
% folder name has spaces, which a URI must percent-encode.
    x = 1;
    f = fullfile(test.tempDir.Folder,"exists.mat");
    save(f,"x");
    pth = replace(string([f; fullfile(test.tempDir.Folder,"missing.mat")]), ...
        filesep, "/");
    pth = replace(pth, " ", "%20");
    if prefix == "file:///"
        pth = strip(pth,"left","/");
    end
    yes = prefix + pth(1);
    no = prefix + pth(2);
end
