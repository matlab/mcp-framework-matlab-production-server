classdef tListFallback < matlab.unittest.TestCase
% Test prodserver.mcp.handler.listFallback (unrecognized */list requests get
% 204 No Content with the request id echoed).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tReturns204NoContent(test)
            jrpc.jsonrpc = "2.0";
            jrpc.id = 42;
            [result, httpCode, httpMsg] = ...
                prodserver.mcp.handler.listFallback(jrpc);
            test.verifyEqual(httpCode, 204);
            test.verifyEqual(httpMsg, 'No Content');
            test.verifyEqual(result.id, 42);
            test.verifyEqual(result.jsonrpc, "2.0");
        end

    end

end
