classdef tIssid < matlab.unittest.TestCase
% Test prodserver.mcp.validation.issid (is X a well-formed session id —
% text, correct prefix, exactly three separators).

% Copyright 2026 The MathWorks, Inc.

    properties
        validSID
    end

    methods (TestClassSetup)
        function buildSID(test)
            import prodserver.mcp.internal.Constants
            sep = Constants.SessionIDSep;
            prefix = Constants.SessionIDPrefix + sep + Constants.SessionIDType;
            test.validSID = prefix + sep + "myrealm" + sep + "1234";
        end
    end

    methods (Test)

        function tValidSessionID(test)
            import prodserver.mcp.validation.issid
            test.verifyTrue(issid(test.validSID));
        end

        function tValidCharVector(test)
            % A char vector with the same content is also accepted.
            import prodserver.mcp.validation.issid
            test.verifyTrue(issid(char(test.validSID)));
        end

        function tNonTextIsNotSID(test)
            import prodserver.mcp.validation.issid
            test.verifyFalse(issid(5));
        end

        function tEmptyIsNotSID(test)
            import prodserver.mcp.validation.issid
            test.verifyFalse(issid([]));
        end

        function tWrongPrefix(test)
            import prodserver.mcp.validation.issid
            test.verifyFalse(issid("nope"));
        end

        function tTooFewSeparators(test)
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.validation.issid
            sep = Constants.SessionIDSep;
            missingID = Constants.SessionIDPrefix + sep + Constants.SessionIDType + ...
                sep + "realm";
            test.verifyFalse(issid(missingID));
        end

    end

end
