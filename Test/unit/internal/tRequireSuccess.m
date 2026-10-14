classdef tRequireSuccess < matlab.unittest.TestCase
% Test prodserver.mcp.internal.requireSuccess (raise a descriptive error when
% an HTTP response indicates failure; pass silently on success).

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        URI = "http://localhost/x";
    end

    methods

        function r = response(~, code, data)
            import matlab.net.http.ResponseMessage
            import matlab.net.http.MessageBody
            if nargin < 3
                r = ResponseMessage(code);
            else
                r = ResponseMessage(code, [], MessageBody(data));
            end
        end

    end

    methods (Test)

        function tSuccessPassesSilently(test)
            import matlab.net.http.StatusCode
            test.verifyWarningFree(@() prodserver.mcp.internal.requireSuccess( ...
                test.response(StatusCode.OK), test.URI));
        end

        function tClientErrorNoBody(test)
            % A 4xx below 500 raises HttpError (no remote-protocol inspection).
            import matlab.net.http.StatusCode
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                test.response(StatusCode.NotFound), test.URI), ...
                "prodserver:mcp:HttpError");
        end

        function tClientErrorWithBody(test)
            import matlab.net.http.StatusCode
            r = test.response(StatusCode.NotFound, 'short body');
            test.verifyError(@() prodserver.mcp.internal.requireSuccess(r, test.URI), ...
                "prodserver:mcp:HttpError");
        end

        function tJsonRpcErrorOnOkIsRemoteError(test)
            % The regression test. Client-level JSON-RPC codes -- parse error,
            % invalid request, method not found, invalid params, resource not
            % found -- are protocol failures, not transport failures, so the
            % server answers HTTP 200 and puts the error in the body. The body
            % inspection used to be gated on a failing status, so every one of
            % them passed silently here and the caller failed further down on
            % the absence of a result, reporting a missing field instead of the
            % reason the server gave for not sending one.
            import matlab.net.http.StatusCode
            body.jsonrpc = "2.0";
            body.id = 1;
            body.error.message = "Tool 'nope' not available on this MCP server.";
            body.error.code = -32602;
            r = test.response(StatusCode.OK, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:RemoteError');
                % The server's own explanation must survive, not be replaced by
                % a complaint about the field it is carried in.
                test.verifyTrue(contains(err.message, "not available"), ...
                    "The server's message must reach the caller");
                test.verifyTrue(contains(err.message, "-32602"), ...
                    "The JSON-RPC code must reach the caller");
            end
        end

        function tResultIsErrorOnOkIsToolError(test)
            % The regression test for tool errors. An isError result over HTTP
            % 200 is how the server reports a tool that ran and raised. It used
            % to be inspected only on a 5xx, so it passed here as a success and
            % prodserver.mcp.call either raised NoStructuredContent or returned
            % the error text as the tool's output.
            import matlab.net.http.StatusCode
            body.jsonrpc = "2.0";
            body.id = 1;
            body.result.isError = true;
            body.result.content.type = "text";
            body.result.content.text = "tool failed";
            r = test.response(StatusCode.OK, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:ToolError');
                test.verifyTrue(contains(err.message, "tool failed"), ...
                    "The tool's message must reach the caller");
            end
        end

        function tResultIsErrorFalsePasses(test)
            % isError false is an explicit success, not a failure.
            import matlab.net.http.StatusCode
            body.result.isError = false;
            body.result.content.text = "fine";
            r = test.response(StatusCode.OK, body);
            test.verifyWarningFree(@() prodserver.mcp.internal.requireSuccess( ...
                r, test.URI));
        end

        function tResultIsErrorWithoutTextStillReports(test)
            % An isError result with no text content is still a tool error. The
            % reporting code must not fail on the absent text.
            import matlab.net.http.StatusCode
            body.result.isError = true;
            r = test.response(StatusCode.OK, body);
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                r, test.URI), "prodserver:mcp:ToolError");
        end

        function tBareErrorFieldIsNotAJsonRpcError(test)
            % signatureHandler answers an unsupported verb with
            % struct('error', <char>) -- a field named error that is not a
            % JSON-RPC error object. Testing for the error member alone would
            % index a code that is not there, so a reportable HTTP failure would
            % become an indexing failure inside the reporting code.
            import matlab.net.http.StatusCode
            body = struct('error', 'Only GET and POST methods are supported.');
            r = test.response(StatusCode.MethodNotAllowed, body);
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                r, test.URI), "prodserver:mcp:HttpError");
        end

        function tErrorWithoutMessageStillReports(test)
            % JSON-RPC requires message alongside code, but a server that omits
            % it must not turn a reportable protocol error into an indexing
            % failure. The code alone still says what went wrong.
            import matlab.net.http.StatusCode
            body.error.code = -32600;
            r = test.response(StatusCode.OK, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:RemoteError');
                test.verifyTrue(contains(err.message, "-32600"));
            end
        end

        function tServerErrorJsonRpcError(test)
            % A 500 carrying a JSON-RPC error object surfaces RemoteError.
            import matlab.net.http.StatusCode
            body.error.message = "boom";
            body.error.code = -32000;
            r = test.response(StatusCode.InternalServerError, body);
            test.verifyError(@() prodserver.mcp.internal.requireSuccess(r, test.URI), ...
                "prodserver:mcp:RemoteError");
        end

        function tServerErrorResultIsError(test)
            % result.isError is a tool error whatever status carries it.
            import matlab.net.http.StatusCode
            body.result.isError = true;
            body.result.content.text = "tool failed";
            r = test.response(StatusCode.InternalServerError, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:ToolError');
                test.verifyTrue(contains(err.message, "tool failed"));
            end
        end

        function tCustomFailureThreshold(test)
            % Lowering the failure threshold turns a 200 into a failure.
            import matlab.net.http.StatusCode
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                test.response(StatusCode.OK), test.URI, failure=200), ...
                "prodserver:mcp:HttpError");
        end

        function tRequestNameInMessage(test)
            import matlab.net.http.StatusCode
            try
                prodserver.mcp.internal.requireSuccess( ...
                    test.response(StatusCode.NotFound), test.URI, request="myReq");
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyTrue(contains(err.message, "myReq"));
            end
        end

        function tLongBodyTruncated(test)
            % A long char body is truncated with an ellipsis in the message.
            import matlab.net.http.StatusCode
            r = test.response(StatusCode.NotFound, repmat('x', 1, 200));
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyTrue(contains(err.message, "..."));
            end
        end

        function tLargeStructSummarized(test)
            % A large struct body is summarized by its field names.
            import matlab.net.http.StatusCode
            for k = 1:20
                body.("field" + k) = k;
            end
            r = test.response(StatusCode.NotFound, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyTrue(contains(err.message, "JSON object with fields"));
            end
        end

    end

end
