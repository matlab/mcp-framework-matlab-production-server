classdef tSanitizeForURI < matlab.unittest.TestCase
% Test prodserver.mcp.io.sanitizeForURI (replace URI-reserved characters with
% underscore so a string is safe to use in a URI).

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tNoReservedCharsUnchanged(test)
            import prodserver.mcp.io.sanitizeForURI
            test.verifyEqual(sanitizeForURI("plain"), "plain");
        end

        function tWholeReservedStringReplaced(test)
            % The full reserved set as one substring collapses to a single "_".
            import prodserver.mcp.io.sanitizeForURI
            allBad = strjoin(prodserver.mcp.internal.Constants.InvalidInURI',"");
            test.verifyEqual(sanitizeForURI(allBad), ...
                string(repelem('_', numel(prodserver.mcp.internal.Constants.InvalidInURI))));
        end

        function tReplacesSingleReservedChar(test)
            % Intended behavior: each reserved character is replaced individually.
            import prodserver.mcp.io.sanitizeForURI
            rc = char(prodserver.mcp.internal.Constants.InvalidInURI);
            N = numel(rc);
            for n = 1:numel(rc)
                test.verifyEqual(sanitizeForURI("a"+string(rc(n))+"b"+string(rc(N-n+1))+"c"), "a_b_c");
            end

        end

    end

end
