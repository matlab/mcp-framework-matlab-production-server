classdef tRedactedURIs < MockCaller
% Client messages show an endpoint or server address without its user
% information or query, which may hold a password or a token: every error
% and warning that shows one passes it through prodserver.mcp.io.redactURI,
% as the metrics Catalog's display does. Each test gives a URL with a
% password, Secret, and checks that what the user is shown doesn't have it.
%
% Not tRedactURI: feature/externalize has a test of that name, of
% redactURI and of a function this branch doesn't have.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Secret = "s3cr3tSENTINEL"
    end

    properties (Access = private)
        Endpoint
    end

    methods (TestMethodSetup)
        function startServer(test)
            config = fullfile(fileparts(mfilename("fullpath")), ...
                "tRedactedURIs.yaml");
            test.Endpoint = test.startMcpServer(config, threaded=true);
            prodserver.mcp.client.Adapter.create(action="clearAll");
            test.addTeardown(@() prodserver.mcp.client.Adapter.create( ...
                action="clearAll"));
        end
    end

    methods (Static, Hidden)
        function err = listOrError(ep)
        % list(EP)'s error, so evalc can complete and keep its warnings.
            err = [];
            try
                prodserver.mcp.list(ep, "Tool", retry=1, delay=0.1);
            catch err
            end
        end
    end

    methods (Access = private)

        function ep = credentialed(test, path, server)
        % An address with user information whose password is Secret.
            if nargin < 3
                server = MockCaller.Host + ":" + test.port;
            end
            ep = "http://alice:" + test.Secret + "@" + server + path;
        end

        function verifyReportHasNoSecret(test, me, where)
        % Neither ME's message nor any cause's, as MATLAB would show them.
            report = string(me.getReport("extended", hyperlinks="off"));
            test.verifyNoSecret(report, where);
        end

        function verifyNoSecret(test, text, where)
            test.verifyFalse(contains(text, test.Secret), ...
                where + " shows the password: " + text);
            test.verifyFalse(contains(text, "alice"), ...
                where + " shows the user name: " + text);
        end

    end

    methods (Test)

        function redactURIRemovesUserInformationAndQuery(test)
            f = @prodserver.mcp.io.redactURI;
            test.verifyEqual(f("https://user:pw@host.example/a/b.csv?sig=SENTINEL"), ...
                "https://host.example/a/b.csv (query removed)");
            test.verifyEqual(f("https://a@b@host/p"), "https://host/p", ...
                "The last @ ends the user information.");
            for u = ["http://localhost:9910/x/mcp", "file:////server/share/x.mat", ""]
                test.verifyEqual(f(u), u, u);
            end
        end

        function redactURIRemovesRawPasswords(test)
        % A password typed without percent-encoding can hold characters
        % that end the authority early; it is removed all the same.
            f = @prodserver.mcp.io.redactURI;
            for pw = ["pa/ss", "pa?ss", "pa#ss", "pa@ss", "pa/s?s#s"]
                u = "http://alice:" + pw + "@host:9910/x/mcp";
                r = f(u);
                test.verifyTrue(startsWith(r, "http://host:9910/x/mcp"), u + " -> " + r);
                test.verifyFalse(contains(r, ["alice", "pa"]), u + " -> " + r);
            end
            test.verifyEqual(f("  http://alice:pw@host/x "), "http://host/x", ...
                "Surrounding whitespace");
            test.verifyEqual(f("http://[::1]:9910/x"), "http://[::1]:9910/x");
            % An "@" after the authority is the path's or the query's own.
            test.verifyEqual(f("http://host:9910/x?mail=a@b.com"), ...
                "http://host:9910/x (query removed)");
            test.verifyEqual(f("http://host:9910/data/user@x/f.csv"), ...
                "http://host:9910/data/user@x/f.csv");
            test.verifyEqual(f("http://host/data/user@x/f.csv"), ...
                "http://host/data/user@x/f.csv");
            test.verifyEqual(f("http://alice:pw@host:9910/x?mail=a@b.com"), ...
                "http://host:9910/x (query removed)");
            test.verifyEqual(f("http://alice:pa/ss@host:9910/x?mail=a@b.com"), ...
                "http://host:9910/x (query removed)");
            test.verifyEqual(f("http://alice:pw@[::1]:9910/x"), "http://[::1]:9910/x");
        end

        function transportErrorsShowNoPassword(test)
        % MATLAB's own error for a connection that fails, which quotes the
        % address it was given, is raised with the address redacted and
        % the same identifier, by each function that sends a request.
            ep = test.credentialed("/x/mcp", "127.0.0.1:1");
            calls = {
                "call",  @() prodserver.mcp.call(ep, "f", 1, retry=1, delay=0.1)
                "list",  @() prodserver.mcp.list(ep, "Tool", retry=1, delay=0.1)
                "read",  @() prodserver.mcp.read(ep, "mcp://r", retry=1, delay=0.1)
                "exist", @() prodserver.mcp.exist(ep, "f", "Tool", retry=1, delay=0.1)
                };
            for k = 1:size(calls, 1)
                try
                    calls{k,2}();
                    test.verifyFail(calls{k,1} + " should have failed.");
                catch me
                    test.verifyTrue(startsWith(me.identifier, "MATLAB:webservices:"), ...
                        calls{k,1} + ": " + me.identifier);
                    test.verifyReportHasNoSecret(me, calls{k,1});
                    test.verifySubstring(me.message, "127.0.0.1:1", calls{k,1});
                end
            end
        end

        function timeoutCauseShowsNoPassword(test)
        % RequestTimeout carries the transport's error as its cause.
            ep = test.credentialed("/slow/mcp");
            try
                prodserver.mcp.list(ep, "Tool", retry=1, delay=0.1, timeout=2);
                test.verifyFail("list should have timed out.");
            catch me
                test.verifyEqual(me.identifier, 'prodserver:mcp:RequestTimeout');
                test.assertNotEmpty(me.cause, "The transport's error is its cause.");
                test.verifyReportHasNoSecret(me, "RequestTimeout");
            end
        end

        function metricsUnknownHostShowsNoPassword(test)
            try
                prodserver.mcp.metrics(test.credentialed("/x/mcp", "nosuchhost.invalid"), ...
                    retry=1, delay=0.1, timeout=5);
                test.verifyFail("Expected an error for an unknown host.");
            catch me
                test.verifyReportHasNoSecret(me, "metrics " + me.identifier);
            end
        end

        function deployListingErrorShowsNoPassword(test)
        % The archive listing's 403, raised as MATLAB's error, which quotes
        % the URL and its query.
            folder = string(test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            ctf = fullfile(folder, "tool.ctf");
            fclose(fopen(ctf, "w"));
            try
                prodserver.mcp.deploy(ctf, test.credentialed(""), ...
                    retry=1, delay=0.1, timeout=5);
                test.verifyFail("Expected the listing's 403.");
            catch me
                test.verifySubstring(me.identifier, "403", me.message);
                test.verifyReportHasNoSecret(me, "deploy");
                test.verifyFalse(contains(me.message, "ctf=tool"), ...
                    "The query is removed: " + me.message);
            end
        end

        function unknownArchive(test)
            ep = test.credentialed("/gone/mcp");
            output = string(evalc("err = tRedactedURIs.listOrError(ep);"));
            test.assertNotEmpty(err);
            test.verifyEqual(err.identifier, 'prodserver:mcp:UnknownArchive');
            test.verifyNoSecret(err.message, "UnknownArchive");
            test.verifySubstring(err.message, MockCaller.Host, ...
                "The address is still there, without its user information.");
            test.verifySubstring(output, "Warning: ", "It warned.");
            test.verifyNoSecret(output, "WaitingForArchive");
        end

        function httpAndServerErrors(test)
            % requireSuccess formats every HttpError, ServerError,
            % RemoteError and ToolError.
            uri = test.credentialed("/x/mcp", "localhost:9910");
            for status = [404 500]
                r = matlab.net.http.ResponseMessage( ...
                    matlab.net.http.StatusCode(status), [], ...
                    matlab.net.http.MessageBody("not JSON"));
                try
                    prodserver.mcp.internal.requireSuccess(r, uri, request="ping");
                    test.verifyFail("Expected an error for " + status + ".");
                catch me
                    test.verifyTrue(startsWith(me.identifier, "prodserver:mcp:"), ...
                        me.identifier);
                    test.verifyNoSecret(me.message, me.identifier);
                end
            end
        end

        function metricsServerUnresponsive(test)
            for ep = [test.credentialed("/x/mcp", "localhost:1"), ...
                    test.credentialed("", "localhost:1")]
                try
                    prodserver.mcp.metrics(ep, retry=1, delay=0.1, timeout=5);
                    test.verifyFail("Expected ServerUnresponsive.");
                catch me
                    test.verifyEqual(me.identifier, 'prodserver:mcp:ServerUnresponsive');
                    test.verifyNoSecret(me.message, "metrics");
                end
            end
        end

        function deployServerUnresponsive(test)
            folder = string(test.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            ctf = fullfile(folder, "tool.ctf");
            fclose(fopen(ctf, "w"));
            try
                prodserver.mcp.deploy(ctf, test.credentialed("", "localhost:1"), ...
                    retry=1, delay=0.1, timeout=5);
                test.verifyFail("Expected ServerUnresponsive.");
            catch me
                test.verifyEqual(me.identifier, 'prodserver:mcp:ServerUnresponsive');
                test.verifyNoSecret(me.message, "deploy");
            end
        end

        function invalidAddresses(test)
            % The validators echo the address they refuse.
            raw = @(pw, path) "http://alice:" + pw + "@host:9910" + path;
            cases = {
                @prodserver.mcp.validation.mustBeMCPServer, ...
                    test.credentialed("/x/notmcp", "host:9910")
                @prodserver.mcp.validation.mustBeURI, ...
                    test.credentialed("/a b", "host:9910")
                @prodserver.mcp.validation.mustBeMCPServer, ...
                    raw(test.Secret + "/x", "/x/mcp")
                @prodserver.mcp.validation.mustBeMCPServer, ...
                    raw("p?" + test.Secret, "/x/mcp")
                @prodserver.mcp.validation.mustBeMCPServer, ...
                    " " + test.credentialed("/x/mcp", "host:9910")
                @prodserver.mcp.validation.mustBeURI, ...
                    raw(test.Secret + "/x", "/a b")
                };
            for k = 1:size(cases, 1)
                try
                    cases{k,1}(cases{k,2});
                    test.verifyFail("Expected an error for case " + k);
                catch me
                    test.verifyTrue(startsWith(me.identifier, "prodserver:mcp:"), ...
                        "Case " + k + ": " + me.identifier);
                    test.verifyNoSecret(me.message, "Case " + k);
                end
            end
        end

        function catalogDisplay(test)
            % Its own expression ended the user information at the first @:
            % a@b:secret@host showed b:secret@host.
            data = ["# TYPE matlabprodserver_up_time_seconds counter"; ...
                "matlabprodserver_up_time_seconds 1"];
            c = prodserver.mcp.metrics.Catalog(data, ...
                "http://a@alice:" + test.Secret + "@localhost:9910/x/mcp"); %#ok<NASGU>
            out = string(evalc("disp(c)"));
            test.verifyNoSecret(out, "Catalog display");
            test.verifySubstring(out, "http://localhost:9910");
        end

    end
end
