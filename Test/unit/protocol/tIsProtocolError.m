classdef tIsProtocolError < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.isProtocolError (true for the errors that may
% indicate a stale cached protocol, which exist.m, list.m, call.m and read.m
% answer by clearing the cache and retrying once).

% Copyright 2026 The MathWorks, Inc.

    methods (Access = private)

        function tf = check(~, identifier)
            try
                error(identifier, 'synthetic');
            catch me
                tf = prodserver.mcp.protocol.isProtocolError(me);
            end
        end

    end

    methods (Test)

        function tRemoteErrorIsAProtocolError(test)
            % This arm is load-bearing. requireSuccess now parses a JSON-RPC
            % error body at any failing status, so a stale cached protocol
            % arrives as RemoteError (an id-bearing -32020/-32022/-32601)
            % where it previously arrived as a bare HttpError. Without this
            % arm the cache-clear-and-retry silently stops firing and the
            % client never recovers from a server that changed protocol.
            test.verifyTrue(test.check('prodserver:mcp:RemoteError'));
        end

        function tHttpErrorIsAProtocolError(test)
            test.verifyTrue(test.check('prodserver:mcp:HttpError'));
        end

        function tUnattributableRequestIsAProtocolError(test)
            test.verifyTrue(test.check('prodserver:mcp:UnattributableRequest'));
        end

        function tNoSessionFromServerIsAProtocolError(test)
            test.verifyTrue(test.check('prodserver:mcp:NoSessionFromServer'));
        end

        function tMethodNotFoundIsAProtocolError(test)
            test.verifyTrue(test.check('prodserver:mcp:MethodNotFound'));
        end

        function tUnrelatedErrorIsNot(test)
            % The retry must not fire for a failure that clearing the cache
            % cannot possibly fix.
            test.verifyFalse(test.check('MATLAB:nonExistentField'));
            test.verifyFalse(test.check('prodserver:mcp:BadInputArguments'));
            test.verifyFalse(test.check('prodserver:mcp:ToolUnavailable'));
        end

        function tToolAndFinalJsonRpcErrorsAreNot(test)
            % requireSuccess raises these after the request reached a tool,
            % or with a code that no revision change can fix. A retry would
            % at best repeat the failure and at worst run the tool twice.
            test.verifyFalse(test.check('prodserver:mcp:ToolError'));
            test.verifyFalse(test.check('prodserver:mcp:JsonRpcError'));
            % A bare 5xx: the server may have failed after the tool ran.
            test.verifyFalse(test.check('prodserver:mcp:ServerError'));
        end

    end

end
