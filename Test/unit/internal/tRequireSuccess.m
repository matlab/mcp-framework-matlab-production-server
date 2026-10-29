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

        function tServerErrorIsNotHttpError(test)
            % A 5xx without a JSON-RPC error may follow a tool that ran, so
            % it must not carry the identifier isProtocolError retries on.
            import matlab.net.http.StatusCode
            for code = [StatusCode.InternalServerError, StatusCode.BadGateway]
                try
                    prodserver.mcp.internal.requireSuccess( ...
                        test.response(code), test.URI);
                    test.verifyFail("Expected requireSuccess to throw.");
                catch err
                    test.verifyEqual(err.identifier, ...
                        'prodserver:mcp:ServerError', string(code));
                    test.verifyFalse( ...
                        prodserver.mcp.protocol.isProtocolError(err), ...
                        string(code));
                end
            end
        end

        function tClientErrorWithBody(test)
            import matlab.net.http.StatusCode
            r = test.response(StatusCode.NotFound, 'short body');
            test.verifyError(@() prodserver.mcp.internal.requireSuccess(r, test.URI), ...
                "prodserver:mcp:HttpError");
        end

        function tClientErrorJsonRpcErrorIsRemoteError(test)
            % 2026-07-28 mandates 400 for an unsupported protocol version, a
            % header mismatch and a missing required _meta field, and 404 for
            % an unimplemented method. Each carries a structured JSON-RPC
            % error whose message is far more useful than the bare status
            % line, so the body must be parsed at ANY failing status -- not
            % only at >= 500, which was the old gate.
            import matlab.net.http.StatusCode
            body.error.message = "Unsupported protocol version";
            body.error.code = -32022;
            r = test.response(StatusCode.BadRequest, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:RemoteError');
                test.verifyTrue(contains(err.message, ...
                    "Unsupported protocol version"), ...
                    "The server's own message must survive: " + err.message);
                test.verifyTrue(contains(err.message, "-32022"), ...
                    "The JSON-RPC code must be reported: " + err.message);
            end
        end

        function tNotFoundJsonRpcErrorIsRemoteError(test)
            % 2026-07-28 reports an unimplemented method as HTTP 404 with
            % -32601, which must not be flattened into a bare HttpError.
            import matlab.net.http.StatusCode
            body.error.message = "Method not found";
            body.error.code = -32601;
            r = test.response(StatusCode.NotFound, body);
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                r, test.URI), "prodserver:mcp:RemoteError");
        end

        function tSuccessWithIsErrorIsToolError(test)
            % Inverted in conformance Phase XA (XD32). A tool that ran and
            % failed is reported in band, over HTTP 200 -- and a caller that
            % asked for the tool's outputs must get an error, not the error
            % text in place of them. ToolError deliberately does not match
            % isProtocolError: the tool ran, so a retry would run it again.
            import matlab.net.http.StatusCode
            body.result.isError = 1;
            body.result.content.type = "text";
            body.result.content.text = "tool rejected its input";
            r = test.response(StatusCode.OK, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:ToolError');
                test.verifyTrue(contains(err.message, "tool rejected its input"), ...
                    err.message);
                test.verifyFalse(prodserver.mcp.protocol.isProtocolError(err), ...
                    "A tool error must never trigger clear-cache-and-retry");
            end
        end

        function tSuccessWithJsonRpcErrorIsAFailure(test)
            % Inverted in conformance Phase XA (ND5). A JSON-RPC error over
            % 200 is how 2025-06-18 reports an unknown tool or bad
            % arguments; swallowing it left the caller with no outputs and
            % no explanation. -32602 is final, so it is not retryable.
            import matlab.net.http.StatusCode
            body.error.message = "Unknown tool: invalid_tool_name";
            body.error.code = -32602;
            r = test.response(StatusCode.OK, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:JsonRpcError');
                test.verifyTrue(contains(err.message, "invalid_tool_name"), ...
                    err.message);
                test.verifyTrue(contains(err.message, "-32602"), err.message);
                test.verifyFalse(prodserver.mcp.protocol.isProtocolError(err));
            end
        end

        function tMethodNotFoundOver200IsRemoteError(test)
            % -32601 can mean "you are speaking the wrong revision", so it
            % keeps the retryable identifier at any status.
            import matlab.net.http.StatusCode
            body.error.message = "Method not found";
            body.error.code = -32601;
            r = test.response(StatusCode.OK, body);
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                r, test.URI), "prodserver:mcp:RemoteError");
        end

        function tServerErrorJsonRpcError(test)
            % A 500 carrying a JSON-RPC error object raises JsonRpcError, not
            % RemoteError (changed in conformance Phase XA). Only the
            % stale-protocol codes are retryable; -32603 in particular can
            % follow tool execution, and a retry would run the tool twice.
            import matlab.net.http.StatusCode
            for code = [-32000 -32603]
                body.error.message = "boom";
                body.error.code = code;
                r = test.response(StatusCode.InternalServerError, body);
                test.verifyError(@() prodserver.mcp.internal.requireSuccess(r, test.URI), ...
                    "prodserver:mcp:JsonRpcError", "code " + code);
            end
        end

        function tServerErrorResultIsError(test)
            % A 500 carrying result.isError raises ToolError with the text
            % (was RemoteError before conformance Phase XA).
            import matlab.net.http.StatusCode
            body.result.isError = 1;
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

        function tToolErrorJoinsEveryTextItem(test)
            % content decodes as a struct array when the items share
            % fields and as a cell array when they do not. Both must yield
            % every text item, and a non-text item must not crash.
            import matlab.net.http.StatusCode
            same.result.isError = true;
            same.result.content = struct('type', {"text","text"}, ...
                'text', {"first", "second"});
            mixed.result.isError = true;
            mixed.result.content = {struct('type',"image",'data',"AAAA"), ...
                struct('type',"text",'text',"third")};
            cases = {same, ["first","second"]; mixed, "third"};
            for k = 1:size(cases,1)
                r = test.response(StatusCode.OK, cases{k,1});
                try
                    prodserver.mcp.internal.requireSuccess(r, test.URI);
                    test.verifyFail("Expected requireSuccess to throw.");
                catch err
                    test.verifyEqual(err.identifier, 'prodserver:mcp:ToolError');
                    for t = cases{k,2}
                        test.verifyTrue(contains(err.message, t), err.message);
                    end
                end
            end
        end

        function tNonStructErrorMemberDoesNotCrash(test)
            % ND6: a body whose 'error' member is not an error object must
            % not be dereferenced as one. Over 200 it is simply a success;
            % over 500 it is a ServerError carrying the body.
            import matlab.net.http.StatusCode
            body.error = "not an object";
            test.verifyWarningFree(@() prodserver.mcp.internal.requireSuccess( ...
                test.response(StatusCode.OK, body), test.URI));
            test.verifyError(@() prodserver.mcp.internal.requireSuccess( ...
                test.response(StatusCode.InternalServerError, body), test.URI), ...
                "prodserver:mcp:ServerError");
        end

        function tToleratedStatusIgnoresBody(test)
            % terminate passes failure=500 so that any 4xx is acceptable.
            % That tolerance covers the body too.
            import matlab.net.http.StatusCode
            body.error.message = "Bad Request";
            body.error.code = -32600;
            test.verifyWarningFree(@() prodserver.mcp.internal.requireSuccess( ...
                test.response(StatusCode.BadRequest, body), test.URI, ...
                failure=500));
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
