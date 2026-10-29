classdef tIsTransientError < matlab.unittest.TestCase
% Test prodserver.mcp.internal.isTransientError: the one place that decides
% whether a raised failure can change while the request does not.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        refused = {MException("MATLAB:webservices:ConnectionRefused", "x"), ...
            MException("a:b", "Could not connect to server"), ...
            MException("a:b", "Connection refused: connect")}
        timedOut = {MException("MATLAB:webservices:Timeout", "x"), ...
            MException("a:b", "The server did not respond: timed out"), ...
            MException("a:b", "Read timeout")}
        retryableStatus = {404, 408, 429}
    end

    methods (Static, Access = private)
        function me = http(code)
            me = MException(sprintf("MATLAB:webservices:HTTP%d", code), ...
                "Status %d", code);
        end
    end

    methods (Test)

        function refusedConnectionCounts(test, refused)
            import prodserver.mcp.internal.isTransientError
            test.verifyTrue(isTransientError(refused));
            test.verifyFalse(isTransientError(refused, connection=false, ...
                timeout=false));
        end

        function timeoutCounts(test, timedOut)
            import prodserver.mcp.internal.isTransientError
            test.verifyTrue(isTransientError(timedOut));
            test.verifyFalse(isTransientError(timedOut, timeout=false));
        end

        function retryableStatusCounts(test, retryableStatus)
            import prodserver.mcp.internal.isTransientError
            me = test.http(retryableStatus);
            test.verifyTrue(isTransientError(me));
            test.verifyFalse(isTransientError(me, status=[]));
        end

        function defaultStatusesAreTheConstant(test)
            % The HTTPnnn identifiers are derived from RetryableStatus, not
            % kept as a second list that can drift from it.
            import prodserver.mcp.internal.isTransientError
            for code = [400 401 403 405 409 410 415]
                test.verifyFalse(isTransientError(test.http(code)), ...
                    string(code));
            end
            for code = prodserver.mcp.internal.Constants.RetryableStatus
                test.verifyTrue(isTransientError(test.http(code)), ...
                    string(code));
            end
        end

        function statusSubsetIsHonored(test)
            % ping retries only 404.
            import prodserver.mcp.internal.isTransientError
            test.verifyTrue(isTransientError(test.http(404), status=404));
            test.verifyFalse(isTransientError(test.http(429), status=404));
        end

        function serverErrorsOnlyWhenAsked(test)
            import prodserver.mcp.internal.isTransientError
            for code = [500 502 503]
                test.verifyFalse(isTransientError(test.http(code)), ...
                    string(code));
                test.verifyTrue(isTransientError(test.http(code), ...
                    serverErrors=true), string(code));
            end
        end

        function causeChainIsSearched(test)
            % matlab.net.http reports a timeout through a cause.
            import prodserver.mcp.internal.isTransientError
            top = MException("MATLAB:http:Generic", "Request failed");
            inner = MException("a:b", "Operation timed out");
            top = top.addCause(MException("a:c", "wrapper").addCause(inner));
            test.verifyTrue(isTransientError(top));
            test.verifyFalse(isTransientError(top, timeout=false));
        end

        function unrelatedErrorIsNot(test)
            import prodserver.mcp.internal.isTransientError
            test.verifyFalse(isTransientError(MException( ...
                "MATLAB:nonExistentField", "Unrecognized field name")));
            test.verifyFalse(isTransientError(MException( ...
                "prodserver:mcp:ArchiveManagementDisabled", "disabled"), ...
                serverErrors=true));
        end

    end
end
