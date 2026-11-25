classdef tIsRequestId < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.isRequestId: a request id MCP allows, as
% jsondecode delivers it, is a string (empty included) or a whole number.
% validateEnvelope rejects a request whose id isn't; responseId echoes
% only one that is.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % What jsondecode makes of each JSON id, and what MATLAB code
        % might pass for one.
        allowed = struct( ...
            "integer", 7, "negative", -3, "zero", 0, "negativeZero", -0, ...
            "large", 2^53, "int32", int32(5), ...
            "charString", 'abc', "emptyChar", '', ...
            "string", "abc", "emptyString", "")
        refused = struct( ...
            "null", [], "fraction", 1.5, "NaN", NaN, "Inf", Inf, ...
            "complex", 1+2i, "array", [1 2], "charMatrix", ['ab'; 'cd'], ...
            "charColumn", ['a'; 'b'], "missing", string(missing), ...
            "stringArray", ["a" "b"], "boolean", true, ...
            "object", struct('a', 1), "cell", {{1}})
    end

    methods (Test)

        function allowedIds(test, allowed)
            test.verifyTrue(prodserver.mcp.jsonrpc.isRequestId(allowed));
        end

        function refusedIds(test, refused)
            test.verifyFalse(prodserver.mcp.jsonrpc.isRequestId(refused));
        end

    end
end
