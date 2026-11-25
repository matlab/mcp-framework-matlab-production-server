classdef tSetup < matlab.unittest.TestCase
% Test prodserver.mcp.agent.setup against a stand-in claude command, first
% on the PATH, and a Claude Code configuration folder of the test's own
% (CLAUDE_CONFIG_DIR). The stand-in logs every call and answers as the
% environment says:
%
%   STUB_CLAUDE_LOG       File each call's arguments are appended to
%   STUB_CLAUDE_LIST      What "plugin marketplace list" prints
%   STUB_CLAUDE_ADD_EXIT  Exit status of "plugin marketplace add". Not 0:
%                         it prints an error wrapped in terminal escapes,
%                         as Claude Code does.
%   STUB_CLAUDE_ADD_OK_FOR  A folder "plugin marketplace add" succeeds for,
%                         whatever STUB_CLAUDE_ADD_EXIT says.
%
% Up to 1.6.0, a failed add made setup write known_marketplaces.json
% itself, in a form Claude Code rejects, breaking every marketplace.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Name = "mcp-framework-matlab-production-server"
    end

    properties
        configDir
        log
    end

    properties (TestParameter)
        % Where the bad member is in the file: the comma to remove differs.
        position = struct("first", 1, "middle", 2, "last", 3)
    end

    methods (TestMethodSetup)
        function standIn(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            stubDir = string(test.applyFixture(TemporaryFolderFixture).Folder);
            writeStub(stubDir);
            test.configDir = string(test.applyFixture(TemporaryFolderFixture).Folder);
            test.log = fullfile(stubDir, "calls.log");
            test.applyFixture(EnvironmentVariableFixture("PATH", ...
                stubDir + pathsep + getenv("PATH")));
            test.applyFixture(EnvironmentVariableFixture( ...
                "CLAUDE_CONFIG_DIR", test.configDir));
            test.applyFixture(EnvironmentVariableFixture( ...
                "STUB_CLAUDE_LOG", test.log));
            test.applyFixture(EnvironmentVariableFixture( ...
                "STUB_CLAUDE_LIST", ""));
            test.applyFixture(EnvironmentVariableFixture( ...
                "STUB_CLAUDE_ADD_EXIT", "0"));
            test.applyFixture(EnvironmentVariableFixture( ...
                "STUB_CLAUDE_ADD_OK_FOR", "none"));
        end
    end

    methods (Test)

        function registersWithClaude(test)
            out = evalc("prodserver.mcp.agent.setup");
            test.verifyTrue(any(contains(test.calls(), ...
                "plugin marketplace add")), "Registered with Claude's own command.");
            test.verifySubstring(out, "registered for: Claude Code");
            test.verifyFalse(isfolder(fullfile(test.configDir, "plugins")), ...
                "setup writes nothing of Claude Code's.");
        end

        function alreadyRegisteredIsLeftAlone(test)
            % From this copy of the framework, however the path is spelt.
            here = replace(prodserver.mcp.internal.packageFolder(), "/", "\");
            test.writeKnown(registered(here + "\"));
            out = evalc("prodserver.mcp.agent.setup");
            test.verifyFalse(any(contains(test.calls(), ...
                "plugin marketplace add")), "Not added twice.");
            test.verifyFalse(any(contains(test.calls(), "remove")));
            test.verifySubstring(out, "already registered");
        end

        function registeredElsewhereIsReplaced(test)
            % An earlier clone or install: Claude Code would go on reading
            % its skills, or none if it's gone.
            test.writeKnown(registered("/home/u/old-clone"));
            out = evalc("prodserver.mcp.agent.setup");
            c = test.calls();
            removed = find(contains(c, "plugin marketplace remove") & ...
                contains(c, test.Name), 1);
            added = find(contains(c, "plugin marketplace add"), 1);
            test.assertNotEmpty(removed, "The old registration removed.");
            test.assertNotEmpty(added, "This copy added.");
            test.verifyLessThan(removed, added, "Removed, then added.");
            test.verifySubstring(out, "/home/u/old-clone");
        end

        function renamedEntryIsReplaced(test)
            % 1.6.0 rewrote the file through jsondecode, renaming the
            % framework's key; Claude Code knows the entry by that name, so
            % that is the name to remove, even if it points here.
            here = prodserver.mcp.internal.packageFolder();
            for folder = ["/home/u/old-clone", here]
                if isfile(test.log), delete(test.log); end
                test.writeKnown(replace(registered(folder), test.Name, ...
                    replace(test.Name, "-", "_")));
                evalc("prodserver.mcp.agent.setup");
                c = test.calls();
                removed = find(contains(c, "plugin marketplace remove") & ...
                    contains(c, replace(test.Name, "-", "_")), 1);
                added = find(contains(c, "plugin marketplace add"), 1);
                test.assertNotEmpty(removed, "Removed by its renamed key: " + folder);
                test.assertNotEmpty(added, "Added under its own name: " + folder);
                test.verifyLessThan(removed, added, folder);
            end
        end

        function failedReplacementRestoresTheOld(test)
            % The old registration was removed before an add that failed:
            % setup registers it again, and says so.
            old = string(test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            test.writeKnown(registered(old));
            setenv("STUB_CLAUDE_ADD_EXIT", "1");
            setenv("STUB_CLAUDE_ADD_OK_FOR", old);
            try
                evalc("prodserver.mcp.agent.setup");
                test.verifyFail("Expected ClaudeInstallFailed.");
            catch me
                test.verifyEqual(me.identifier, 'prodserver:mcp:ClaudeInstallFailed');
                test.verifySubstring(me.message, "registered from " + old + " again");
            end
            c = test.calls();
            c = c(strlength(strtrim(c)) > 0);
            test.verifyTrue(contains(c(end), "plugin marketplace add") && ...
                contains(c(end), old), "The old folder added last: " + c(end));
        end

        function failedReplacementSaysHowToRestore(test)
            % If the old folder can't be added either, the error says how.
            test.writeKnown(registered("/home/u/gone-clone"));
            setenv("STUB_CLAUDE_ADD_EXIT", "1");
            try
                evalc("prodserver.mcp.agent.setup");
                test.verifyFail("Expected ClaudeInstallFailed.");
            catch me
                test.verifySubstring(me.message, "couldn't restore it");
                test.verifySubstring(me.message, ...
                    "claude plugin marketplace add ""/home/u/gone-clone""");
            end
        end

        function otherKindOfSourceIsLeftAlone(test)
            % Registered from GitHub, say: the user's choice, not a stale
            % folder.
            test.writeKnown("{""" + test.Name + """: {""source"": " + ...
                "{""source"": ""github"", ""repo"": ""mathworks/x""}}}");
            out = evalc("prodserver.mcp.agent.setup");
            test.verifyFalse(any(contains(test.calls(), "plugin marketplace add")));
            test.verifyFalse(any(contains(test.calls(), "remove")));
            test.verifySubstring(out, "already registered");
        end

        function unreadableFileAsksClaude(test)
            % Then only claude plugin marketplace list can say, by name,
            % and only the whole name counts.
            test.writeKnown("{ not JSON");
            setenv("STUB_CLAUDE_LIST", test.Name + "-dev");
            evalc("prodserver.mcp.agent.setup");
            test.verifyTrue(any(contains(test.calls(), ...
                "plugin marketplace add")), "Another marketplace's name.");
            setenv("STUB_CLAUDE_LIST", "  " + test.Name + "  /opt/mcp");
            delete(test.log);
            out = evalc("prodserver.mcp.agent.setup");
            test.verifyFalse(any(contains(test.calls(), ...
                "plugin marketplace add")), "Its own name.");
            test.verifySubstring(out, "already registered");
        end

        function failedAddRaisesAndWritesNothing(test)
            setenv("STUB_CLAUDE_ADD_EXIT", "1");
            try
                evalc("prodserver.mcp.agent.setup");
                test.verifyFail("Expected ClaudeInstallFailed.");
            catch me
                test.verifyEqual(me.identifier, ...
                    'prodserver:mcp:ClaudeInstallFailed');
                test.verifySubstring(me.message, "stub failure", ...
                    "Claude's own message.");
                test.verifySubstring(me.message, ...
                    "claude plugin marketplace add", "What to run by hand.");
                test.verifyFalse(contains(me.message, char(27)), ...
                    "No terminal escapes.");
            end
            test.verifyFalse(isfolder(fullfile(test.configDir, "plugins")), ...
                "Nothing written in Claude Code's folder.");
        end

        function repairsTheOldEntry(test, position)
            % The other members' text, keys with '-' included, survives
            % byte for byte: jsondecode would make my-marketplace
            % my_marketplace.
            [original, kept] = knownMarketplaces(position, test.Name);
            file = test.writeKnown(original);
            out = evalc("prodserver.mcp.agent.setup");
            repaired = string(fileread(file));
            test.verifyFalse(contains(repaired, """marketplaces"""));
            test.verifyEqual(regexprep(repaired, "\s", ""), ...
                regexprep(kept, "\s", ""), "Only that member removed.");
            test.verifyWarningFree(@() jsondecode(repaired), "Still JSON.");
            test.verifyEqual(string(fileread(file + ".bak")), original, ...
                "The original is kept.");
            test.verifySubstring(out, "Repaired");
        end

        function foreignMarketplacesKeyIsLeftAlone(test)
            original = knownMarketplaces(2, "someone-else");
            file = test.writeKnown(original);
            test.verifyWarning(@() evalc("prodserver.mcp.agent.setup"), ...
                "prodserver:mcp:UnknownMarketplacesKey");
            test.verifyEqual(string(fileread(file)), original);
            test.verifyFalse(isfile(file + ".bak"));
        end

        function healthyFileIsUntouched(test)
            original = "{" + newline + ...
                "  ""claude-plugins-official"": {""source"": {""source"": ""github"", ""repo"": ""a/b""}}" + ...
                newline + "}";
            file = test.writeKnown(original);
            evalc("prodserver.mcp.agent.setup");
            test.verifyEqual(string(fileread(file)), original);
            test.verifyFalse(isfile(file + ".bak"));
        end

    end

    methods (Access = private)

        function c = calls(test)
            c = string.empty;
            if isfile(test.log)
                c = readlines(test.log);
            end
        end

        function file = writeKnown(test, txt)
            folder = fullfile(test.configDir, "plugins");
            mkdir(folder);
            file = fullfile(folder, "known_marketplaces.json");
            fid = fopen(file, "w");
            fwrite(fid, unicode2native(txt, "UTF-8"));
            fclose(fid);
        end

    end

end

function txt = registered(folder)
% A healthy known_marketplaces.json registering the framework's
% marketplace from FOLDER, as Claude Code writes it.
    path = jsonencode(string(folder));
    txt = "{" + newline + ...
        "  ""claude-plugins-official"": {""source"": {""source"": ""github"", ""repo"": ""a/b""}}," + newline + ...
        "  ""mcp-framework-matlab-production-server"": {" + newline + ...
        "    ""source"": {""source"": ""directory"", ""path"": " + path + "}," + newline + ...
        "    ""installLocation"": " + path + newline + "  }" + newline + "}";
end

function [txt, kept] = knownMarketplaces(position, name)
% A known_marketplaces.json with two real members and the "marketplaces"
% array setup up to 1.6.0 wrote, at POSITION, with entries named NAME.
% KEPT is the file without that array.
    real = [
        "  ""claude-plugins-official"": {" + newline + ...
        "    ""source"": {""source"": ""github"", ""repo"": ""anthropics/claude-plugins""}," + newline + ...
        "    ""installLocation"": ""/home/u/.claude/plugins/x""" + newline + "  }"
        "  ""mw_agent_plugins_marketplace"": {""source"": {""source"": ""directory"", ""path"": ""/opt/mw [x]""}}"];
    bad = "  ""marketplaces"": [" + newline + ...
        "    {""name"": """ + name + """, ""source"": ""/opt/mcp"", ""installedAt"": ""/opt/mcp""}" + ...
        newline + "  ]";
    members = real;
    members = [members(1:position-1); bad; members(position:end)];
    txt = "{" + newline + strjoin(members, "," + newline) + newline + "}";
    kept = "{" + newline + strjoin(real, "," + newline) + newline + "}";
end

function writeStub(folder)
% A stand-in for the claude command, in FOLDER.
    esc = char(27);
    if ispc
        lines = [
            "@echo off"
            "echo %*>>""%STUB_CLAUDE_LOG%"""
            "if ""%~1""==""--version"" exit /b 0"
            "if ""%~3""==""list"" goto list"
            "if ""%~3""==""add"" goto add"
            "exit /b 0"
            ":list"
            "if defined STUB_CLAUDE_LIST echo %STUB_CLAUDE_LIST%"
            "exit /b 0"
            ":add"
            "if ""%STUB_CLAUDE_ADD_EXIT%""==""0"" exit /b 0"
            "if ""%~4""==""%STUB_CLAUDE_ADD_OK_FOR%"" exit /b 0"
            "echo " + esc + "[?25hFailed to add marketplace: stub failure" + esc + "[?25h"
            "exit /b %STUB_CLAUDE_ADD_EXIT%"];
        writelines(lines, fullfile(folder, "claude.bat"));
    else
        lines = [
            "#!/bin/sh"
            "echo ""$*"" >> ""$STUB_CLAUDE_LOG"""
            "case ""$1 $2 $3"" in"
            "  --version*) exit 0;;"
            "  ""plugin marketplace list"") [ -n ""$STUB_CLAUDE_LIST"" ] && echo ""$STUB_CLAUDE_LIST""; exit 0;;"
            "  ""plugin marketplace add"") [ ""$STUB_CLAUDE_ADD_EXIT"" = 0 ] && exit 0"
            "    [ ""$4"" = ""$STUB_CLAUDE_ADD_OK_FOR"" ] && exit 0"
            "    printf '\033[?25hFailed to add marketplace: stub failure\033[?25h\n'"
            "    exit ""$STUB_CLAUDE_ADD_EXIT"";;"
            "esac"
            "exit 0"];
        stub = fullfile(folder, "claude");
        writelines(lines, stub);
        system("chmod +x """ + stub + """");
    end
end
