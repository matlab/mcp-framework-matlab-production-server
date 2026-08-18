classdef tRedAlert < matlab.unittest.TestCase
% Test prodserver.mcp.internal.redAlert (raise an internal error with the
% prodserver:mcp:internal: prefix).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tThrowsPrefixedError(test)
            import prodserver.mcp.internal.redAlert
            test.verifyError(@() redAlert("Boom", "went wrong"), ...
                "prodserver:mcp:internal:Boom");
        end

        function tFormatsMessageArgs(test)
            % Trailing args are sprintf-style substituted into the message.
            import prodserver.mcp.internal.redAlert
            try
                redAlert("Boom", "x=%d", 5);
                test.verifyFail("Expected redAlert to throw.");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:internal:Boom');
                test.verifyEqual(err.message, 'x=5');
            end
        end

    end

end
