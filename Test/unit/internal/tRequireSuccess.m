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
            % A 500 carrying result.isError surfaces RemoteError with the text.
            import matlab.net.http.StatusCode
            body.result.isError = 1;
            body.result.content.text = "tool failed";
            r = test.response(StatusCode.InternalServerError, body);
            try
                prodserver.mcp.internal.requireSuccess(r, test.URI);
                test.verifyFail("Expected requireSuccess to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:RemoteError');
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
