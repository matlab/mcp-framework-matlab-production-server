classdef tReplaceStringsInFile < matlab.unittest.TestCase
% Test prodserver.mcp.internal.replaceStringsInFile, which build uses to
% stamp the archive name into the routes JSON templates. The templates mark
% their placeholders with <> delimiters, so these tests do too. Every file
% is created in a temporary folder the test removes; read-only files are
% made writable again before the folder is deleted.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        % Shaped like instance_routes.json: one tag, used several times.
        Routes = join([
            "{"
            "    ""version"": ""<Version>"","
            "    ""pathmap"": ["
            "      {"
            "        ""match"": ""^/<Archive>/mcp$"","
            "        ""webhandler"": {"
            "            ""component"": ""<Archive>"","
            "            ""function"": ""prodserver.mcp.internal.mcpHandler"""
            "        }"
            "      },"
            "      {"
            "        ""match"": ""^/<Archive>/ping$"","
            "        ""webhandler"": {"
            "            ""component"": ""<Archive>"","
            "            ""function"": ""prodserver.mcp.internal.pingHandler"""
            "        }"
            "      }"
            "    ]"
            "}"
            ], newline)
    end

    properties (SetAccess = private)
        Folder string
    end

    methods (TestMethodSetup)
        function makeFolder(test)
            test.Folder = test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
        end
    end

    methods (Test)

        function replacesEveryTagInWritableFile(test)
            file = test.makeFile("routes.json", test.Routes, false);

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");

            test.verifyEqual(readText(file), ...
                replace(test.Routes, "<Archive>", "myArchive"));
            test.verifyRoutesFor(file, "myArchive");
        end

        function replacesEveryTagInReadOnlyFile(test)
            file = test.makeFile("routes.json", test.Routes, true);
            test.assertFalse(isWritable(file), ...
                "Precondition: the file must start read-only");

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");

            test.verifyEqual(readText(file), ...
                replace(test.Routes, "<Archive>", "myArchive"));
            test.verifyRoutesFor(file, "myArchive");
            test.verifyTrue(isWritable(file), ...
                "A read-only file is made writable in order to update it");
        end

        function writableFileNeedsNoAttributeChange(test)
            % A file we can already write must not depend on being able to
            % set its attributes: on Linux that requires owning the file.
            file = test.makeFile("routes.json", test.Routes, false);
            test.shadowFileattrib();

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");

            test.verifyRoutesFor(file, "myArchive");
        end

        function failsWhenFileCannotBeMadeWritable(test)
            file = test.makeFile("routes.json", test.Routes, true);
            test.shadowFileattrib();

            replaceTags = @() prodserver.mcp.internal.replaceStringsInFile( ...
                file, "<Archive>", "myArchive");
            test.verifyError(replaceTags, "prodserver:mcp:FileNotWritable");

            % Actionable: names the file, passes on the reason, says what
            % to do about it. (verifyError returns the function's outputs,
            % not the exception, so catch it to read the message.)
            try
                replaceTags();
                err = MException.empty;
            catch err
            end
            test.assertNotEmpty(err);
            test.verifySubstring(err.message, file);
            test.verifySubstring(err.message, "Access is denied");
            test.verifySubstring(err.message, "Make the file writable");
            test.verifyEqual(readText(file), test.Routes, ...
                "A failed update must leave the file untouched");
        end

        function replacesSeveralDifferentTags(test)
            file = test.makeFile("routes.json", test.Routes, false);

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                ["<Archive>", "<Version>"], ["myArchive", "2.0.1"]);

            routes = jsondecode(readText(file));
            test.verifyEqual(string(routes.version), "2.0.1");
            test.verifyRoutesFor(file, "myArchive");
        end

        function onlyExactTagsAreReplaced(test)
            % Matching is literal and case-sensitive: the delimiters are
            % part of the tag.
            text = "{""a"": ""<Archive>"", ""b"": ""<archive>""," + ...
                " ""c"": ""Archive"", ""d"": ""<Archive"", ""e"": ""Archive>""}";
            file = test.makeFile("tags.json", text, false);

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");

            s = jsondecode(readText(file));
            test.verifyEqual(string(s.a), "myArchive");
            test.verifyEqual(string(s.b), "<archive>");
            test.verifyEqual(string(s.c), "Archive");
            test.verifyEqual(string(s.d), "<Archive");
            test.verifyEqual(string(s.e), "Archive>");
        end

        function fileWithoutTagsIsUnchanged(test)
            text = replace(test.Routes, "<Archive>", "fixed");
            file = test.makeFile("routes.json", text, true);

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");

            test.verifyEqual(readText(file), text);
        end

        function returnsTheFileName(test)
            file = test.makeFile("routes.json", test.Routes, false);
            out = prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");
            test.verifyEqual(out, file);
        end

        function shippedInstanceRoutesTemplate(test)
            % The real template, copied out the way build copies it, and
            % made read-only as it would be under a read-only install.
            template = fullfile(fileparts(which( ...
                "prodserver.mcp.internal.replaceStringsInFile")), ...
                "instance_routes.json");
            file = fullfile(test.Folder, "instance_routes.json");
            test.assertTrue(copyfile(template, file));
            test.makeReadOnly(file);

            prodserver.mcp.internal.replaceStringsInFile(file, ...
                "<Archive>", "myArchive");

            test.verifyFalse(contains(readText(file), "<Archive>"));
            test.verifyRoutesFor(file, "myArchive");
        end

    end

    methods (Access = private)

        function file = makeFile(test, name, text, readOnly)
        % Write TEXT to NAME in the temporary folder, exactly as given.
            file = fullfile(test.Folder, name);
            fid = fopen(file, "w");
            test.assertGreaterThan(fid, 0, "Cannot create " + file);
            fwrite(fid, unicode2native(text, "UTF-8"));
            fclose(fid);
            if readOnly
                test.makeReadOnly(file);
            end
        end

        function makeReadOnly(test, file)
        % Registered after the folder fixture, so this teardown runs first,
        % and the folder can then be deleted.
            test.assertTrue(fileattrib(file, "-w"), ...
                "Cannot make " + file + " read-only");
            test.addTeardown(@() fileattrib(file, "+w"));
        end

        function verifyRoutesFor(test, file, archive)
        % FILE is valid JSON in which every route belongs to ARCHIVE.
            routes = jsondecode(readText(file));
            for k = 1:numel(routes.pathmap)
                r = routes.pathmap(k);
                test.verifyEqual(string(r.webhandler.component), archive);
                test.verifyTrue(startsWith(r.match, "^/" + archive + "/"), ...
                    "Route " + r.match + " should belong to " + archive);
            end
        end

        function shadowFileattrib(test)
        % Put a fileattrib.m ahead of the built-in that refuses every
        % request to add write permission, as it would for a file owned by
        % someone else, and defers to the built-in for everything else.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.SuppressedWarningsFixture

            folder = test.applyFixture(TemporaryFolderFixture).Folder;
            src = [
                "function varargout = fileattrib(varargin)"
                "    if nargin >= 2 && contains(string(varargin{2}), ""+w"")"
                "        varargout = {false, 'Access is denied.', 'MATLAB:FILEATTRIB:CannotSet'};"
                "        varargout = varargout(1:max(nargout,1));"
                "        return"
                "    end"
                "    [varargout{1:nargout}] = builtin(""fileattrib"", varargin{:});"
                "end"
                ];
            writelines(src, fullfile(folder, "fileattrib.m"));
            test.applyFixture(SuppressedWarningsFixture( ...
                "MATLAB:dispatcher:nameConflict"));
            test.applyFixture(PathFixture(folder));
        end

    end
end

function text = readText(file)
% The file's text with line endings normalized and trailing newlines
% removed: writelines terminates with the platform's line ending.
    text = string(fileread(file));
    text = replace(text, sprintf("\r\n"), newline);
    text = strip(text, "right", newline);
end

function tf = isWritable(file)
    [~, attr] = fileattrib(file);
    tf = logical(attr.UserWrite);
end
