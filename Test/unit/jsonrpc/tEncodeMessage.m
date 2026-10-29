classdef tEncodeMessage < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.encodeMessage (wire-name alias replacement).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tRestoreRenamesKeysOnly(test)
            % A key is renamed, compact or pretty; the same text in a
            % string value is not.
            pairs = {"x_meta", "_meta"; "io_ui", "io.modelcontextprotocol/ui"};
            f = @prodserver.mcp.jsonrpc.restoreFieldNames;
            test.verifyEqual(f('{"x_meta":{"io_ui":1},"s":"x_meta"}', pairs), ...
                '{"_meta":{"io.modelcontextprotocol/ui":1},"s":"x_meta"}');
            pretty = jsonencode(struct('x_meta', 1), PrettyPrint=true);
            test.verifyTrue(contains(f(pretty, pairs), '"_meta"'));
            test.verifyEqual(f('{"a":"\"x_meta\":"}', pairs), '{"a":"\"x_meta\":"}');
        end

        function tDefsReplaced(test)
            import prodserver.mcp.jsonrpc.encodeMessage
            s.jsonrpc = "2.0";
            s.result.tools.inputSchema.dollarDefs.x.type = "number";
            json = encodeMessage(s);
            test.verifySubstring(json, '"$defs"');
            test.verifyEmpty(strfind(json, 'dollarDefs'));
        end

        function tMetaReplaced(test)
            import prodserver.mcp.jsonrpc.encodeMessage
            s.jsonrpc = "2.0";
            s.result.x_meta.serverInfo.name = "test";
            json = encodeMessage(s);
            test.verifySubstring(json, '"_meta"');
            test.verifyEmpty(strfind(json, 'x_meta'));
        end

        function tBothReplaced(test)
            import prodserver.mcp.jsonrpc.encodeMessage
            s.jsonrpc = "2.0";
            s.result.x_meta.serverInfo.name = "test";
            s.result.tools.inputSchema.dollarDefs.x.type = "number";
            json = encodeMessage(s);
            test.verifySubstring(json, '"$defs"');
            test.verifySubstring(json, '"_meta"');
            test.verifyEmpty(strfind(json, 'dollarDefs'));
            test.verifyEmpty(strfind(json, 'x_meta'));
        end

        function tPassthroughUnchanged(test)
            import prodserver.mcp.jsonrpc.encodeMessage
            s.jsonrpc = "2.0";
            s.id = 1;
            s.result.tools = struct('name', 'test');
            json = encodeMessage(s);
            expected = jsonencode(s);
            test.verifyEqual(json, expected);
        end

        function tStringValuesUnchanged(test)
        % Only keys are renamed. Tool output, descriptions and resource
        % text that mention the MATLAB-side names must arrive intact.
            import prodserver.mcp.jsonrpc.encodeMessage
            text = ["x_meta", "dollarDefs", "s.x_meta = 1", ...
                '{"x_meta":1,"dollarDefs":2}'];
            s.jsonrpc = "2.0";
            s.result.content = struct("type", "text", "text", num2cell(text));
            decoded = jsondecode(encodeMessage(s));
            test.verifyEqual(string({decoded.result.content.text}), text);
        end

        function tNestedKeysReplaced(test)
        % Keys inside struct arrays follow { and are renamed too.
            import prodserver.mcp.jsonrpc.encodeMessage
            s.result.tools = struct("name", {"a","b"}, ...
                "x_meta", {struct("k",1), struct("k",2)});
            json = encodeMessage(s);
            test.verifyEmpty(strfind(json, 'x_meta'));
            test.verifyEqual(numel(strfind(json, '"_meta":')), 2);
        end

        function tReturnsChar(test)
            import prodserver.mcp.jsonrpc.encodeMessage
            s.x_meta.k = 1;
            test.verifyClass(encodeMessage(s), "char");
        end

    end

end
