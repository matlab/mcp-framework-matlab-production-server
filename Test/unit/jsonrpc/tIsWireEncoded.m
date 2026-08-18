classdef tIsWireEncoded < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.isWireEncoded (recognise wire-encoded values).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tNumericScalar(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            test.verifyTrue(isWireEncoded(5));
        end

        function tLogicalScalar(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            test.verifyTrue(isWireEncoded(true));
        end

        function tNonScalarStringArrayRejected(test)
            % A non-scalar string cannot convert unambiguously to char.
            import prodserver.mcp.jsonrpc.isWireEncoded
            test.verifyFalse(isWireEncoded(["a", "b"]));
        end

        function tNonJSONCharRejected(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            test.verifyFalse(isWireEncoded('not json'));
        end

        function tPlainStructRejected(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            s.foo = 1;
            test.verifyFalse(isWireEncoded(s));
        end

        function tComplexScalar(test)
            % {"re","im"} with no "type" is a valid complex-scalar encoding.
            import prodserver.mcp.jsonrpc.isWireEncoded
            c.re = 1;
            c.im = 2;
            test.verifyTrue(isWireEncoded(c));
        end

        function tComplexWithExtraFieldRejected(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            c.re = 1;
            c.im = 2;
            c.extra = 3;
            test.verifyFalse(isWireEncoded(c));
        end

        function tDurationScalar(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            d.type = 'duration';
            d.seconds = 10;
            test.verifyTrue(isWireEncoded(d));
        end

        function tTypedWrapper(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            w.type = 'double';
            w.size = [1 1];
            w.data = 5;
            test.verifyTrue(isWireEncoded(w));
        end

        function tTypedWrapperUnknownFieldRejected(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            w.type = 'double';
            w.size = [1 1];
            w.data = 5;
            w.bogus = 1;
            test.verifyFalse(isWireEncoded(w));
        end

        function tTableEncoding(test)
            import prodserver.mcp.jsonrpc.isWireEncoded
            t.type = 'table';
            t.rows = 2;
            t.variables = {};
            test.verifyTrue(isWireEncoded(t));
        end

        function tJSONStringOfScalar(test)
            % A char that jsondecodes to a numeric scalar is wire-encoded.
            import prodserver.mcp.jsonrpc.isWireEncoded
            test.verifyTrue(isWireEncoded('5'));
        end

    end

end
