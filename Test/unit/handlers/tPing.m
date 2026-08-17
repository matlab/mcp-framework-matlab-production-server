classdef tPing < matlab.unittest.TestCase
% Test prodserver.mcp.handler.ping (handle the MCP ping request: echo the id
% with an empty result and 200 OK).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tReturnsEmptyResultWithId(test)
            jrpc.jsonrpc = "2.0";
            jrpc.id = 42;
            [result, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.ping(jrpc);
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(httpMsg, 'OK');
            test.verifyEqual(result.id, 42);
            test.verifyEqual(result.jsonrpc, "2.0");
            test.verifyEmpty(fieldnames(result.result));
            test.verifyEmpty(msgHeaders);
        end

    end

end
