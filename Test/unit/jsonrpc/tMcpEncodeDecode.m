classdef tMcpEncodeDecode < matlab.unittest.TestCase
% Test mcpEncode and mcpDecode dispatch logic for each WireEncoding mode.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tEncodeInvertibleProducesWrapper(test)
            import prodserver.mcp.jsonrpc.mcpEncode
            import prodserver.mcp.WireEncoding

            encoded = mcpEncode(WireEncoding.Invertible, [1 2 3]);
            w = encoded{1};
            test.verifyTrue(isstruct(w));
            test.verifyEqual(string(w.type), "double");
            test.verifyEqual(w.size, [1 3]);
        end

        function tEncodeJSONPassthrough(test)
            import prodserver.mcp.jsonrpc.mcpEncode
            import prodserver.mcp.WireEncoding

            encoded = mcpEncode(WireEncoding.JSON, 42);
            test.verifyEqual(encoded{1}, 42);
        end

        function tEncodeHybridProducesWrapper(test)
            import prodserver.mcp.jsonrpc.mcpEncode
            import prodserver.mcp.WireEncoding

            encoded = mcpEncode(WireEncoding.Hybrid, [4 5 6]);
            w = encoded{1};
            test.verifyTrue(isstruct(w));
            test.verifyEqual(string(w.type), "double");
        end

        function tDecodeInvertibleUnwraps(test)
            import prodserver.mcp.jsonrpc.mcpDecode
            import prodserver.mcp.WireEncoding

            wrapper = struct("type", "double", "size", [1 1], "data", 7);
            decoded = mcpDecode(WireEncoding.Invertible, wrapper);
            test.verifyEqual(decoded{1}, 7);
        end

        function tDecodeJSONPassthrough(test)
            import prodserver.mcp.jsonrpc.mcpDecode
            import prodserver.mcp.WireEncoding

            decoded = mcpDecode(WireEncoding.JSON, 99);
            test.verifyEqual(decoded{1}, 99);
        end

        function tDecodeHybridUnwraps(test)
            import prodserver.mcp.jsonrpc.mcpDecode
            import prodserver.mcp.WireEncoding

            wrapper = struct("type", "double", "size", [1 1], "data", 7);
            decoded = mcpDecode(WireEncoding.Hybrid, wrapper);
            test.verifyEqual(decoded{1}, 7);
        end

        function tMultipleValuesEncode(test)
            import prodserver.mcp.jsonrpc.mcpEncode
            import prodserver.mcp.WireEncoding

            encoded = mcpEncode(WireEncoding.JSON, 1, "hello", true);
            test.verifyLength(encoded, 3);
            test.verifyEqual(encoded{1}, 1);
            test.verifyEqual(encoded{2}, "hello");
            test.verifyEqual(encoded{3}, true);
        end

        function tMultipleValuesDecode(test)
            import prodserver.mcp.jsonrpc.mcpDecode
            import prodserver.mcp.WireEncoding

            w1 = struct("type", "double", "size", [1 1], "data", 3);
            w2 = struct("type", "double", "size", [1 1], "data", 5);
            decoded = mcpDecode(WireEncoding.Invertible, w1, w2);
            test.verifyLength(decoded, 2);
            test.verifyEqual(decoded{1}, 3);
            test.verifyEqual(decoded{2}, 5);
        end

        function tRoundTripInvertible(test)
            import prodserver.mcp.jsonrpc.mcpEncode
            import prodserver.mcp.jsonrpc.mcpDecode
            import prodserver.mcp.WireEncoding

            original = uint16([10 20 30]);
            encoded = mcpEncode(WireEncoding.Invertible, original);
            decoded = mcpDecode(WireEncoding.Invertible, encoded{:});
            test.verifyEqual(decoded{1}, original);
        end

    end

end
