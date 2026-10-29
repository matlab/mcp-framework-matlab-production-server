classdef tServerVersion < matlab.unittest.TestCase
% MCPConstants.ServerVersion (reported as serverInfo.version) must be the
% newest release in ReleaseNotes.md, so a release that adds its notes but
% forgets the constant fails here.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function matchesNewestReleaseNotes(test)
            notes = fullfile(prodserver.mcp.internal.packageFolder(), ...
                "ReleaseNotes.md");
            test.assumeTrue(isfile(notes), "ReleaseNotes.md not present");

            % Release headings look like "# 1.4: Sept. 2026".
            heads = regexp(fileread(notes), ...
                "^#\s*(\d+(?:\.\d+)*)\s*:", "tokens", "lineanchors");
            test.assertNotEmpty(heads, "No release headings found");
            released = cellfun(@(t)string(t{1}), heads);

            [~, newest] = max(arrayfun(@versionNumber, released));
            test.verifyEqual(versionNumber(prodserver.mcp.MCPConstants.ServerVersion), ...
                versionNumber(released(newest)), ...
                "MCPConstants.ServerVersion (" + ...
                prodserver.mcp.MCPConstants.ServerVersion + ...
                ") must match the newest release in ReleaseNotes.md (" + ...
                released(newest) + ").");
        end

    end
end

function n = versionNumber(v)
% "1.6" and "1.6.0" are the same release. Three parts, each below 1000.
    parts = double(split(string(v), "."));
    parts(end+1:3) = 0;
    n = parts(1:3)' * [1e6; 1e3; 1];
end
