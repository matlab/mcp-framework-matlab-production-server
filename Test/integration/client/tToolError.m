classdef tToolError < MockCaller
% A tool that raises must make prodserver.mcp.call raise, with the tool's text.
%
% The server reports a tool that ran and raised as HTTP 200 with result.isError,
% which is correct MCP. The client only inspected isError on a 5xx, so the error
% never surfaced. What the caller saw instead depended on the tool: a tool with
% a required output raised NoStructuredContent, which says nothing about why;
% a tool with no declared outputs returned the error content as its first
% output, and did not raise at all.

% Copyright 2026 The MathWorks, Inc.

    methods(Test)

        function declaredOutputToolErrorRaises(test)
        % Used to raise NoStructuredContent, hiding the tool's message.
            endpoint = startMcpServer(test,"tToolError.yaml");

            err = captureError(@()prodserver.mcp.call(endpoint, ...
                "mockDeclared",1),1);

            test.assertNotEmpty(err,"A tool that raised must make call raise");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:ToolError",err.message);
            test.verifyTrue(contains(err.message,"Index exceeds array bounds"), ...
                "The tool's own message must reach the caller: " + err.message);
            test.verifyTrue(contains(err.message,"mockDeclared"), ...
                "The diagnosis must name the tool: " + err.message);
        end

        function undeclaredOutputToolErrorRaises(test)
        % Used to return the error content as output 1, silently. Asked for as
        % a statement too, since that path returns through ans.
            endpoint = startMcpServer(test,"tToolError.yaml");

            for n = [0 1]
                err = captureError(@()prodserver.mcp.call(endpoint, ...
                    "mockUndeclared",2),n);

                test.assertNotEmpty(err,sprintf("A tool that raised must " + ...
                    "make call raise, with %d output(s) requested",n));
                test.verifyEqual(string(err.identifier), ...
                    "prodserver:mcp:ToolError",err.message);
                test.verifyTrue(contains(err.message,"Undefined variable q"), ...
                    "The tool's own message must reach the caller: " + ...
                    err.message);
            end
        end

        function multiPartErrorKeepsEveryPart(test)
        % Two content items decode to a struct array. Indexing .text on it
        % yields a comma-separated list, which the old 5xx-only branch passed
        % into the message's format arguments as two separate values.
            endpoint = startMcpServer(test,"tToolError.yaml");

            err = captureError(@()prodserver.mcp.call(endpoint, ...
                "mockMultiPart",3),1);

            test.assertNotEmpty(err,"A tool that raised must make call raise");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:ToolError",err.message);
            test.verifyTrue(contains(err.message,"first part") && ...
                contains(err.message,"second part"), ...
                "Every text part must reach the caller: " + err.message);
        end
    end

end

function err = captureError(fcn,n)
%captureError Invoke FCN asking for N outputs; return the MException it raised.
%   Empty if it raised none. N may be 0, for a call made as a statement.

    err = MException.empty;
    try
        if n == 0
            fcn();
        else
            out = cell(1,n);
            [out{1:n}] = fcn(); %#ok<NASGU> the outputs are not what is under test
        end
    catch err
    end
end
