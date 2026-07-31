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
    end
end
