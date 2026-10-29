classdef tMessageHeaders < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.messageHeaders: the per-message
% headers 2026-07-28 requires (Mcp-Method always, Mcp-Name for the methods
% that name a thing). The names and the sentinel are literals here, not
% constants, so the test pins the wire format independently of the code.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function methodOnlyWhenNothingIsNamed(test)
            rows = prodserver.mcp.protocol.v20260728.messageHeaders( ...
                struct('method', "tools/list", 'params', struct()));
            test.verifyEqual(rows, {'Mcp-Method', 'tools/list'});
        end

        function toolsCallNamesTheTool(test)
            rows = prodserver.mcp.protocol.v20260728.messageHeaders( ...
                struct('method', "tools/call", ...
                       'params', struct('name', "myTool")));
            test.verifyEqual(rows, ...
                {'Mcp-Method', 'tools/call'; 'Mcp-Name', 'myTool'});
        end

        function nonAsciiNameIsEncoded(test)
            rows = prodserver.mcp.protocol.v20260728.messageHeaders( ...
                struct('method', "resources/read", ...
                       'params', struct('uri', "caf" + string(char(233)))));
            test.verifyEqual(rows{2,1}, 'Mcp-Name');
            % base64(UTF-8 "café") = Y2Fmw6k=
            test.verifyEqual(rows{2,2}, '=?base64?Y2Fmw6k=?=');
        end

        function missingNameIsNotInvented(test)
            rows = prodserver.mcp.protocol.v20260728.messageHeaders( ...
                struct('method', "tools/call", 'params', struct()));
            test.verifyEqual(rows, {'Mcp-Method', 'tools/call'});
        end

        function valuesAreChar(test)
            % Production Server requires char header values.
            rows = prodserver.mcp.protocol.v20260728.messageHeaders( ...
                struct('method', "tools/call", ...
                       'params', struct('name', "t")));
            test.verifyTrue(iscellstr(rows)); %#ok<ISCLSTR>
        end

    end

end
