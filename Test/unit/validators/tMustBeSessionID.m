classdef tMustBeSessionID < matlab.unittest.TestCase
% Test prodserver.mcp.validation.mustBeSessionID (validator: error unless X is
% a well-formed session id).

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

        function tValidSessionIDPasses(test)
            import prodserver.mcp.validation.mustBeSessionID
            test.verifyWarningFree(@() mustBeSessionID(test.validSID));
        end

        function tNonTextErrors(test)
            import prodserver.mcp.validation.mustBeSessionID
            test.verifyError(@() mustBeSessionID(5), ...
                "prodserver:mcp:BadSessionIDType");
        end

        function tMalformedErrors(test)
            import prodserver.mcp.validation.mustBeSessionID
            test.verifyError(@() mustBeSessionID("nope"), ...
                "prodserver:mcp:MalformedSessionID");
        end

    end

end
