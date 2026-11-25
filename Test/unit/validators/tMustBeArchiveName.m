classdef tMustBeArchiveName < matlab.unittest.TestCase
% Test prodserver.mcp.validation.mustBeArchiveName (validator: error unless
% a name has only ASCII letters, digits and '_'), and that build and
% deploy check the archive name before they do anything else. Other names
% used to reach matlab.net.http, which failed with MalformedURL or
% EncodingFailure and didn't say the name was the problem.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        bad = struct("space", "with space", ...
            "nonASCII", string(char([252 110 239 99 248 100 233])), ...
            "dot", "a.b", "slash", "a/b", "query", "a?b=1", ...
            "percent", "a%20b", "empty", "", ...
            "hyphen", "add-one", "leadingHyphen", "-x")
    end

    methods (Test)

        function tValidNamesPass(test)
            import prodserver.mcp.validation.mustBeArchiveName
            names = ["primeSequence", "mcp_Add_2", "1tool", "_", ...
                string(repmat('a', 1, 120))];
            for n = names
                test.verifyWarningFree(@() mustBeArchiveName(n), n);
            end
            test.verifyWarningFree(@() mustBeArchiveName(names), "a list");
        end

        function tInvalidNamesError(test, bad)
            import prodserver.mcp.validation.mustBeArchiveName
            test.verifyError(@() mustBeArchiveName(bad), ...
                "prodserver:mcp:InvalidArchiveName");
        end

        function tMessageSaysWhatIsAllowed(test)
            import prodserver.mcp.validation.mustBeArchiveName
            try
                mustBeArchiveName("with space", "C:\work\with space.ctf");
                test.verifyFail("Expected InvalidArchiveName.");
            catch me
                test.verifySubstring(me.message, "'with space'");
                test.verifySubstring(me.message, ...
                    "letters (A-Z, a-z), digits and '_', not '-' or other characters");
                test.verifySubstring(me.message, "rename the file", ...
                    "Given the file, say how to fix it.");
            end
        end

        function tFrameworkIsReserved(test)
            % An archive named Framework would count its own requests in
            % MCP_Framework_Request, the framework's counter, and MPS would
            % add the two into one row. Other cases are other metrics.
            import prodserver.mcp.validation.mustBeArchiveName
            try
                mustBeArchiveName("Framework", "C:\work\Framework.ctf");
                test.verifyFail("Expected InvalidArchiveName.");
            catch me
                test.verifyEqual(me.identifier, 'prodserver:mcp:InvalidArchiveName');
                test.verifySubstring(me.message, "'Framework' is reserved");
                test.verifySubstring(me.message, "MCP_Framework_Request");
                test.verifySubstring(me.message, "rename the file");
            end
            test.verifyError(@() mustBeArchiveName(["ok", "Framework"]), ...
                "prodserver:mcp:InvalidArchiveName", "In a list.");
            for n = ["framework", "FRAMEWORK", "Framework2", "myFramework"]
                test.verifyWarningFree(@() mustBeArchiveName(n), n);
            end
        end

        function tBuildRefusesFramework(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.verifyError(@() prodserver.mcp.build("toyScalarOne", ...
                archive="Framework", stop="Definition"), ...
                "prodserver:mcp:InvalidArchiveName");
        end

        function tBuildChecksArchive(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.verifyError(@() prodserver.mcp.build("toyScalarOne", ...
                archive="with space", stop="Definition"), ...
                "prodserver:mcp:InvalidArchiveName");
        end

        function tDeployChecksNameFirst(test, bad)
            % An empty file is enough, and a server that isn't there: the
            % name must be rejected before deploy sends anything.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            test.assumeFalse(bad == "" || contains(bad, "/"), ...
                "Not a file name: there is no file to make.");
            folder = test.applyFixture(TemporaryFolderFixture).Folder;
            ctf = fullfile(folder, bad + ".ctf");
            fid = fopen(ctf, "w");
            test.assumeNotEqual(fid, -1, "This file system can't name " + ctf);
            fclose(fid);
            test.verifyError(@() prodserver.mcp.deploy(ctf, ...
                "http://localhost:1", retry=1, timeout=1, delay=1), ...
                "prodserver:mcp:InvalidArchiveName");
        end

    end

end
