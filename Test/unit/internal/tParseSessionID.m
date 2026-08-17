classdef tParseSessionID < matlab.unittest.TestCase
% Test prodserver.mcp.internal.parseSessionID (decompose SID:<type>:<realm>:<id>
% into its parts, returned in most-likely-used order [id, realm, type, sid]).

% Copyright 2026 The MathWorks, Inc.

    properties
        sep
        validSID
    end

    methods (TestClassSetup)
        function buildSID(test)
            import prodserver.mcp.internal.Constants
            test.sep = Constants.SessionIDSep;
            prefix = Constants.SessionIDPrefix + test.sep + Constants.SessionIDType;
            test.validSID = prefix + test.sep + "myrealm" + test.sep + "1234";
        end
    end

    methods (Test)

        function tDecomposesParts(test)
            import prodserver.mcp.internal.Constants
            [id, realm, type, sid] = prodserver.mcp.internal.parseSessionID(test.validSID);
            test.verifyEqual(id, "1234");
            test.verifyEqual(realm, "myrealm");
            test.verifyEqual(type, Constants.SessionIDType);
            test.verifyEqual(sid, Constants.SessionIDPrefix);
        end

        function tInvalidSessionIDErrors(test)
            % The mustBeSessionID validator on the argument rejects bad input.
            test.verifyError(@() prodserver.mcp.internal.parseSessionID("nope"), ...
                "prodserver:mcp:MalformedSessionID");
        end

    end

end
