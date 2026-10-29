classdef tToolsCall < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.toolsCall (build a tools/call request body from
% a tool definition, its signature and a positional argument list).
%
% The definitions here are the DECODED wire forms a real client sees, not
% the structs defineForMCP builds in process: a missing 'required', a
% "required":[] that jsondecode turns into a 0x0 double, and a signature
% with no 'input' member at all, which is what a deployed archive serves for
% a tool with no inputs (ND12).

% Copyright 2026 The MathWorks, Inc.

    methods (Static)

        function def = definition(requiredJson)
            def = jsondecode(['{"name":"t","inputSchema":{"type":"object"' ...
                requiredJson '}}']);
        end

        function sig = signature(names, kinds)
            sig.t.function = "t";
            sig.t.encoding = "JSON";
            if nargin > 0
                % Cellstrs, as jsondecode delivers them.
                sig.t.input.name = cellstr(names);
                sig.t.input.kind = cellstr(kinds);
                sig.t.input.order = cellstr(names);
            end
        end

    end

    methods (Test)

        function tEncodingAgreesWithOutputs(test)
            % toolsCall encodes the inputs as prodserver.mcp.call decodes
            % the outputs: as the signature says, or, with no encoding in
            % it, as the description implies.
            import prodserver.mcp.WireEncoding
            f = @prodserver.mcp.jsonrpc.toolEncoding;
            sig.t.function = "t";
            def = struct('description', "Adds. " + ...
                prodserver.mcp.MCPConstants.WireEncodingRequiredMsg);
            test.verifyEqual(f("t", sig=sig, def=def), WireEncoding.Invertible);
            test.verifyEqual(f("t", sig=sig, def=struct('description', "Adds.")), ...
                WireEncoding.JSON);
            sig.t.encoding = "JSON";
            test.verifyEqual(f("t", sig=sig, def=def), WireEncoding.JSON, ...
                "The signature decides");
            % Encoded accordingly: a wrapper under Invertible.
            def = jsondecode(['{"name":"t","description":"x ' ...
                char(prodserver.mcp.MCPConstants.WireEncodingResourceURI) ...
                '","inputSchema":{"type":"object","required":["a"]}}']);
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, def, struct(), [1 2]);
            test.verifyTrue(isstruct(body.params.arguments.a));
            % No signature at all: JSON, and no definition file is read.
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(',"required":["a"]'), [], [1 2]);
            test.verifyEqual(body.params.arguments.a, [1 2]);
        end

        function tRequiredAbsent(test)
            % XD18: the key is absent for a tool with no required inputs.
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(''), test.signature());
            test.verifyEqual(body.params.name, "t");
            test.verifyEqual(body.params.arguments, struct());
        end

        function tRequiredEmptyArray(test)
            % XD18: "required":[] decodes to a 0x0 double. It used to reach
            % split() and fail.
            def = test.definition(',"required":[]');
            test.assertClass(def.inputSchema.required, "double");
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, def, ...
                test.signature());
            test.verifyEqual(body.params.arguments, struct());
        end

        function tRequiredCell(test)
            % The ordinary case: a decoded list is a cellstr, consumed in
            % order.
            def = test.definition(',"required":["a","b"]');
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, def, ...
                test.signature(["a","b"], ["Required","Required"]), 1, 2);
            test.verifyEqual(body.params.arguments.a, 1);
            test.verifyEqual(body.params.arguments.b, 2);
        end

        function tRequiredValueContainingComma(test)
            % Never split decoded JSON: a name is a name.
            def = test.definition(',"required":["a"]');
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, def, ...
                test.signature("a", "Required"), "x,y");
            test.verifyEqual(string(body.params.arguments.a), "x,y");
        end

        function tTooFewRequired(test)
            def = test.definition(',"required":["a","b"]');
            test.verifyError(@() prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                def, test.signature(["a","b"], ["Required","Required"]), 1), ...
                "prodserver:mcp:MissingRequiredArguments");
        end

        function tOptionalOnly(test)
            % XD11c: with no required inputs the cursor must start at 1, not
            % at whatever an empty for-loop left behind.
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(',"required":[]'), ...
                test.signature(["p","q"], ["Optional","Optional"]), 7);
            test.verifyEqual(body.params.arguments.p, 7);
            test.verifyFalse(isfield(body.params.arguments, "q"));
        end

        function tRequiredThenOptional(test)
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(',"required":["a"]'), ...
                test.signature(["a","p"], ["Required","Optional"]), 1, 2);
            test.verifyEqual(body.params.arguments.a, 1);
            test.verifyEqual(body.params.arguments.p, 2);
        end

        function tNameValueAfterRequired(test)
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(',"required":["a"]'), ...
                test.signature("a", "Required"), 1, "opt", 5);
            test.verifyEqual(body.params.arguments.a, 1);
            test.verifyEqual(body.params.arguments.opt, 5);
        end

        function tNameValueWithNoInputSignature(test)
            % ND12, client side: no 'input' member must not stop name/value
            % arguments from being sent.
            body = prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(''), test.signature(), "opt", 5);
            test.verifyEqual(body.params.arguments.opt, 5);
        end

        function tStrayArgumentIsReported(test)
            % ND7: one argument left over after the required ones used to
            % vanish, because the gate was < rather than <=. And the
            % message's %d now has its argument.
            def = test.definition(',"required":["a"]');
            sig = test.signature("a", "Required");
            try
                prodserver.mcp.jsonrpc.toolsCall("t", 1, def, sig, 1, "stray");
                test.verifyFail("Expected UnevenOptionalArguments");
            catch err
                test.verifyEqual(err.identifier, ...
                    'prodserver:mcp:UnevenOptionalArguments');
                test.verifyTrue(contains(err.message, "(1)"), err.message);
            end
        end

        function tStrayArgumentToZeroInputTool(test)
            test.verifyError(@() prodserver.mcp.jsonrpc.toolsCall("t", 1, ...
                test.definition(''), test.signature(), "stray"), ...
                "prodserver:mcp:UnevenOptionalArguments");
        end

    end

end
