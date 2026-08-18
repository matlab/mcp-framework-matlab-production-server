classdef tMsgid < matlab.unittest.TestCase
% Test prodserver.mcp.internal.msgid (prefix a message id with the catalog root).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tPrependsCatalogRoot(test)
            import prodserver.mcp.internal.msgid
            test.verifyEqual(msgid("SomeError"), "prodserver:mcp:SomeError");
        end

    end

end
