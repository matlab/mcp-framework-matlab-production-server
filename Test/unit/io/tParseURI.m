classdef tParseURI < matlab.unittest.TestCase
    
% Copyright 2026 The MathWorks, Inc.

    methods(Test)
        function fileURI(test)
            uri = "file:////mathworks/file.data";
            u = prodserver.mcp.io.parseURI(uri);
            test.verifyEqual(u.scheme,"file");
            test.verifyTrue(isempty(u.host),"Non-empty host");
            test.verifyEqual(u.port,-1);
            test.verifyEqual(u.path,"//mathworks/file.data");
            test.verifyTrue(isempty(u.query),"Non-empty query");
            test.verifyEqual(u.uri,uri);
        end

        function addressWithoutPath(test)
            % The host and port end at the path, query or fragment -- or at
            % the end, if there's none of them.
            cases = {
                "http://localhost:9910",      "localhost", "9910", ""
                "http://localhost:9910/",     "localhost", "9910", "/"
                "http://localhost:9910?x=1",  "localhost", "9910", ""
                "http://user@host:9910",      "host",      "9910", ""
                };
            for k = 1:size(cases, 1)
                u = prodserver.mcp.io.parseURI(cases{k,1});
                test.verifyEqual(u.host, cases{k,2}, cases{k,1});
                test.verifyEqual(u.port, cases{k,3}, cases{k,1});
                test.verifyEqual(u.path, cases{k,4}, cases{k,1});
            end
            u = prodserver.mcp.io.parseURI("http://localhost");
            test.verifyEqual(u.host, "localhost");
            test.verifyEqual(u.port, -1, "No port");
            u = prodserver.mcp.io.parseURI("http://user@host:9910");
            test.verifyEqual(u.userInfo, "user");
            u = prodserver.mcp.io.parseURI("http://localhost:9910?x=1");
            test.verifyEqual(u.query, "x=1");
        end

        function encodedBackslashIsData(test)
            % A literal \ is a separator; an encoded one is a character.
            u = prodserver.mcp.io.parseURI("file:///tmp/a%5Cb\c.txt");
            test.verifyEqual(u.path, "/tmp/a\b/c.txt");
            u = prodserver.mcp.io.parseURI("file:///tmp/a%2F%2Fb.txt");
            test.verifyEqual(u.path, "/tmp/a//b.txt", "encoded //");
        end

        function fragmentDropped(test)
            u = prodserver.mcp.io.parseURI("file:///tmp/data.csv#row=4");
            test.verifyEqual(u.path, "/tmp/data.csv");
            test.verifyEmpty(u.query);
            u = prodserver.mcp.io.parseURI("http://host:9910/p?x=1&y=2#top");
            test.verifyEqual(u.path, "/p");
            test.verifyEqual(u.query, ["x=1"; "y=2"]);
            u = prodserver.mcp.io.parseURI("http://host:9910/p%23q");
            test.verifyEqual(u.path, "/p#q", "encoded #");
        end

        function missingScheme(test)
            test.verifyError(@()prodserver.mcp.io.parseURI("/data/file.csv"), ...
                "prodserver:mcp:URIMissingScheme");
        end
    end
end
