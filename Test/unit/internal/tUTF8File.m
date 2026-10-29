classdef tUTF8File < matlab.unittest.TestCase
% Test prodserver.mcp.internal.readUTF8 and writeUTF8. They must behave
% like fileread, readlines and writelines, except that characters outside
% the Basic Multilingual Plane survive.

% Copyright 2026 The MathWorks, Inc.

    properties
        folder
    end

    properties (TestParameter)
        % Line structures readlines must agree on. Built with sprintf.
        content = {"a\nb\n", "a\nb", "a\r\nb\r\n", "a\rb", "a\n\nb\n\n", ...
            "", "\n", "a", "été\n日本\r\n"};
    end

    methods (TestMethodSetup)
        function makeFolder(test)
            f = test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            test.folder = f.Folder;
        end
    end

    methods (Test)

        function readMatchesBuiltins(test, content)
            file = test.put(sprintf(content));
            test.verifyEqual(prodserver.mcp.internal.readUTF8(file), ...
                fileread(file, Encoding="UTF-8"));
            test.verifyEqual( ...
                prodserver.mcp.internal.readUTF8(file, Lines=true), ...
                readlines(file, Encoding="UTF-8"));
        end

        function writeMatchesWritelines(test)
            cases = {["a","b"], ["a";"b"], 'ab', "", string.empty, ...
                sprintf("x\ny"), ["été","日本"]};
            for k = 1:numel(cases)
                mine = fullfile(test.folder, "mine.txt");
                theirs = fullfile(test.folder, "theirs.txt");
                prodserver.mcp.internal.writeUTF8(mine, cases{k});
                writelines(cases{k}, theirs);
                test.verifyEqual(bytes(mine), bytes(theirs), "case " + k);

                prodserver.mcp.internal.writeUTF8(mine, cases{k}, ...
                    TrailingLineEnding=false);
                writelines(cases{k}, theirs, TrailingLineEndingRule="never");
                test.verifyEqual(bytes(mine), bytes(theirs), ...
                    "case " + k + ", no trailing line ending");
            end
        end

        function appendAddsToFile(test)
            file = fullfile(test.folder, "a.txt");
            prodserver.mcp.internal.writeUTF8(file, "one");
            prodserver.mcp.internal.writeUTF8(file, "two", Append=true);
            test.verifyEqual( ...
                prodserver.mcp.internal.readUTF8(file, Lines=true), ...
                ["one"; "two"; ""]);
        end

        function outsideBMPRoundTrips(test)
            % fileread, readlines and writelines all turn 😀 into U+001A.
            file = fullfile(test.folder, "emoji.txt");
            prodserver.mcp.internal.writeUTF8(file, ["a😀b", "日本"]);
            test.verifyEqual(bytes(file), [uint8('a'), ...
                uint8([240 159 152 128]), uint8('b'), eol(), ...
                unicode2native('日本', "UTF-8"), eol()]);
            lines = prodserver.mcp.internal.readUTF8(file, Lines=true);
            test.verifyEqual(lines, ["a😀b"; "日本"; ""]);
        end

        function byteOrderMarkRemoved(test)
            file = fullfile(test.folder, "bom.txt");
            fid = fopen(file, "w");
            fwrite(fid, uint8([239 187 191 97 98 99]));   % BOM, then abc
            fclose(fid);
            test.verifyEqual(prodserver.mcp.internal.readUTF8(file), 'abc');
        end

        function parameterDescriptionKeepsOutsideBMP(test)
            % Argument comments become parameter descriptions; reading the
            % function file must not lose them. (The tool description comes
            % from matlab.metadata, which in R2026b turns 😀 into U+001A
            % itself, so it isn't checked here.)
            test.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                test.folder));
            file = fullfile(test.folder, "utf8Tool.m");
            prodserver.mcp.internal.writeUTF8(file, [
                "function y = utf8Tool(x)"
                "% Count 😀 in 日本 text."
                "    arguments"
                "        x (1,1) double  % Number of 😀"
                "    end"
                "    arguments (Output)"
                "        y (1,1) double  % Twice that"
                "    end"
                "    y = 2*x;"
                "end"]);
            defs = prodserver.mcp.internal.mcpDefinition("utf8Tool", ...
                "utf8Tool", encoding="JSON");
            test.verifySubstring(defs.tools.description, "日本");
            test.verifySubstring( ...
                defs.tools.inputSchema.properties.x.description, "Number of 😀");
        end

        function missingFileErrors(test)
            file = fullfile(test.folder, "nope.txt");
            test.verifyError(@() prodserver.mcp.internal.readUTF8(file), ...
                "prodserver:mcp:CannotOpenFile");
            test.verifyError(@() prodserver.mcp.internal.writeUTF8( ...
                fullfile(test.folder, "no", "such", "dir.txt"), "x"), ...
                "prodserver:mcp:CannotOpenFile");
        end

    end

    methods (Access = private)
        function file = put(test, text)
            % Write text's UTF-8 bytes exactly as given.
            file = fullfile(test.folder, "in.txt");
            fid = fopen(file, "w");
            fwrite(fid, unicode2native(char(text), "UTF-8"));
            fclose(fid);
        end
    end
end

function b = bytes(file)
    fid = fopen(file);
    b = fread(fid, inf, "*uint8")';
    fclose(fid);
end

function e = eol()
    if ispc
        e = uint8([13 10]);
    else
        e = uint8(10);
    end
end
