classdef tIsClientMistake < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.isClientMistake (true for the exceptions that
% blame the caller rather than the server, so both revisions' mapErrorCode
% report them as Invalid Params instead of an internal error).
%
% The classification used to be written out twice, once per revision, and the
% two lists had already drifted apart by one identifier. This suite is the
% guard: every identifier is asserted here, so adding a seventh to the shared
% list is a visible decision rather than something that quietly changes the
% status on one protocol and not the other.

% Copyright 2026 The MathWorks, Inc.

    methods (Access = private)

        function tf = check(~, identifier)
            try
                error(identifier, 'synthetic');
            catch me
                tf = prodserver.mcp.protocol.isClientMistake(me);
            end
        end

    end

    methods (Test)

        function tTheWholeSetIsClassified(test)
            % Each of these is a request the server understood and refused:
            % both specs' worked example answers them with
            % {"code": -32602, "message": "Unknown tool: invalid_tool_name"}.
            test.verifyTrue(test.check('prodserver:mcp:BadResourceRead'));
            test.verifyTrue(test.check('prodserver:mcp:AmbiguousResourceURL'));
            test.verifyTrue(test.check('prodserver:mcp:ToolUnavailable'));
            test.verifyTrue(test.check('prodserver:mcp:AmbiguousToolName'));
            test.verifyTrue(test.check('prodserver:mcp:BadInputArguments'));
            test.verifyTrue(test.check('prodserver:mcp:InvalidParams'));
        end

        function tResourceNotFoundIsExcluded(test)
            % Plainly a caller's mistake, and deliberately not here: the two
            % revisions disagree about the code. 2025-06-18 has a dedicated
            % -32002 and 2026-07-28 MUST NOT emit it, so each mapper settles
            % this one itself. Folding it in would silently move 2025-06-18
            % off -32002.
            test.verifyFalse(test.check('prodserver:mcp:ResourceNotFound'));
        end

        function tServerFaultsAreExcluded(test)
            % An internal failure must stay an internal failure: reporting a
            % server bug as Invalid Params tells the caller to fix a request
            % that was correct.
            test.verifyFalse(test.check('MATLAB:nonExistentField'));
            test.verifyFalse(test.check('MATLAB:UndefinedFunction'));
            test.verifyFalse(test.check('prodserver:mcp:InternalError'));
        end

        function tProtocolLevelFailuresAreExcluded(test)
            % These are routing and envelope failures, not bad arguments, and
            % they carry their own codes and statuses. Classifying any of them
            % here would override a mandated 400 with a 200.
            test.verifyFalse(test.check('prodserver:mcp:MissingMeta'));
            test.verifyFalse(test.check('prodserver:mcp:MissingProtocolVersion'));
            test.verifyFalse(test.check('prodserver:mcp:HeaderMismatch'));
            test.verifyFalse(test.check('prodserver:mcp:UnsupportedProtocolVersion'));
            test.verifyFalse(test.check('prodserver:mcp:MethodNotFound'));
        end

    end

end
