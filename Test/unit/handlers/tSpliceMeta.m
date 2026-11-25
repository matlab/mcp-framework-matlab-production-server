classdef tSpliceMeta < matlab.unittest.TestCase
% Test MCPHandlerBase.spliceMeta: a 2026-07-28 test request gains the _meta
% stampMeta adds, in the test's own JSON text, so the server gets the bytes
% the test wrote. Re-encoding the decoded body changed them: [null], which
% jsondecode reads as NaN, came back as null, which it reads as [].

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function addsMetaAndKeepsTheRest(test)
            cases = [
                "{""jsonrpc"":""2.0"",""id"":1,""method"":""tools/call"",""params"":{""name"":""f"",""arguments"":{""x"":[null]}}}"
                "{""jsonrpc"":""2.0"",""id"":1,""method"":""tools/list"",""params"":{}}"
                "{""jsonrpc"":""2.0"",""id"":1,""method"":""ping""}"
                "{ ""id"": 1, ""method"": ""tools/call"", ""params"" : { ""arguments"": {""params"": {""a"": ""}{""}} } }"
                ];
            for body = cases'
                spliced = splice(body);
                test.assertNotEqual(spliced, "", body);
                % The test's own request, as jsondecode reads it, and
                % _meta: nothing else added, changed or lost.
                got = jsondecode(spliced);
                test.assertTrue(isfield(got, "params") && ...
                    isfield(got.params, "x_meta"), spliced);
                test.verifyEqual(string(got.params.x_meta. ...
                    io_modelcontextprotocol_protocolVersion), "2026-07-28");
                got.params = rmfield(got.params, "x_meta");
                want = jsondecode(body);
                if ~isfield(want, "params")
                    test.verifyEmpty(fieldnames(got.params), "Only _meta in params.");
                    got = rmfield(got, "params");
                end
                test.verifyEqual(got, want, spliced);
                test.verifySubstring(spliced, ...
                    """_meta"":{""io.modelcontextprotocol/protocolVersion"":", ...
                    "Named as the client names it.");
            end
            spliced = splice(cases(1));
            test.verifySubstring(spliced, """x"":[null]", ...
                "The test's own text survives, [null] included.");
        end

        function aBodyWithItsOwnMetaIsLeftToDecoding(test)
            % Splicing a second _meta would make a duplicate key.
            body = "{""id"":1,""method"":""ping"",""params"":{""_meta"":{""a"":1}}}";
            test.verifyEqual(splice(body), "");
        end

        function aBodyThatIsNotAnObjectIsLeftAlone(test)
            test.verifyEqual(prodserver.mcp.test.base.MCPHandlerBase.spliceMeta( ...
                "[1,2]", struct()), "");
        end

    end
end

function s = stamped(body)
    s = prodserver.mcp.protocol.v20260728.stampMeta(jsondecode(body));
end

function out = splice(body)
    out = prodserver.mcp.test.base.MCPHandlerBase.spliceMeta(body, stamped(body));
end
