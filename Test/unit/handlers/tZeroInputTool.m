classdef tZeroInputTool < prodserver.mcp.test.base.MCPHandlerBase
% A tool that takes no inputs must be callable.
%
% It was not. A schema for a zero-input tool has no "required" key at all --
% toyZeroInputs.json is literally "inputSchema":{"type":"object"} -- and the
% handler indexed inputSchema.required unguarded, so every call raised
% MATLAB:nonExistentField and surfaced as -32603 Internal Error over HTTP 500.
%
% The second, quieter half of the same bug: the argument-assembly cursor was the
% required-argument loop variable, and MATLAB assigns a loop variable the empty
% range when the loop body never runs. With no required arguments the guard on
% the optional and name-value loops was never satisfied, so a zero-required tool
% silently discarded every optional argument it was given rather than failing
% loudly. The fix is a cursor that does not depend on any loop variable.

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        % Zero-input handling is independent of the wire encoding, but the
        % missing "required" key is produced by defineForMCP under both, so run
        % both arms.
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    methods (TestClassSetup)

        function prepareTools(test, encoding)
            rtt = test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;

            test.fcnNames = "toyZeroInputs";
            test.toolNames = "toyZeroInputs";
            defineTools(test,test.fcnNames,test.toolNames,encoding=encoding);
        end
    end

    methods

        function verifyCallSucceeded(test, response)
            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);

            jrpc = test.responseBody(response);
            test.verifyFalse(isfield(jrpc,"error"), ...
                "A zero-input tool call is not a protocol error");
            test.assertTrue(isfield(jrpc,"result"));
            test.verifyFalse(isfield(jrpc.result,"isError"), ...
                sprintf("Tool reported an execution error: %s", ...
                    jsonencode(jrpc.result)));
            test.verifyTrue(isfield(jrpc.result,"structuredContent"), ...
                "A successful call returns structuredContent");
        end
    end

    methods (Test)

        function tSchemaHasNoRequiredKey(test)
        % The precondition the handler used to assume away. If defineForMCP
        % ever starts emitting "required": [] for a zero-input tool, the
        % guard below stops being exercised and this test says so.
            svc = prodserver.mcp.handler.toolServices;
            d = svc.(prodserver.mcp.MCPConstants.DefinitionVariable);
            t = d.tools{1};
            test.verifyEqual(string(t.name),"toyZeroInputs");
            test.verifyFalse(isfield(t.inputSchema,"required"), ...
                "A zero-input schema is expected to omit required entirely");
        end

        function tCallableWithoutArgumentsMember(test)
        % The natural way a client calls a tool that takes nothing: no
        % arguments member at all.
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/call", ' ...
                    '"params": { "name": "toyZeroInputs" } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyCallSucceeded(response);
        end

        function tCallableWithEmptyArgumentsMember(test)
        % The other way clients spell it -- an empty object -- which must be
        % equivalent.
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/call", ' ...
                    '"params": { "name": "toyZeroInputs", "arguments": {} } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyCallSucceeded(response);
        end

        function tZeroInputToolIsListed(test)
        % tools/list must advertise it, or no client would ever try to call it.
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyEqual(response.HttpCode, 200);
            jrpc = test.responseBody(response);
            names = arrayfun(@(t)string(t.name), jrpc.result.tools);
            test.verifyTrue(ismember("toyZeroInputs", names));
        end

    end
end
