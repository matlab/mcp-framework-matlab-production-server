classdef tIsClassSystemError < matlab.unittest.TestCase
% Test prodserver.mcp.handler.internal.isClassSystemError, which decides
% whether a failed definition load is the multi-MCOS class clash (D37).
%
% The identifiers here are synthetic on purpose. The real class-system
% failures need two archives sharing a worker to provoke, and their exact
% identifiers vary -- which is why the helper matches on catalog prefix and
% why these tests pin the prefix rule, not a list of identifiers.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function classCatalogMatches(test)
            test.verifyTrue(isClass(raise("MATLAB:class:CannotConvert")));
            test.verifyTrue(isClass(raise("MATLAB:class:InvalidEnum")));
        end

        function classUstringCatalogMatches(test)
            % Where the enum-definition messages really live.
            test.verifyTrue(isClass(raise("MATLAB:ClassUstring:BadEnumValueError")));
        end

        function matchDeepInCauseChain(test)
            inner = raise("MATLAB:class:InvalidEnum");
            middle = addCause(raise("MATLAB:load:couldNotReadFile"), inner);
            outer = addCause(raise("pk:wrapper"), middle);
            test.verifyTrue(isClass(outer));
        end

        function matchAmongSeveralCauses(test)
            outer = raise("pk:wrapper");
            outer = addCause(outer, raise("MATLAB:load:unableToReadMatFile"));
            outer = addCause(outer, raise("MATLAB:ClassUstring:MissingMember"));
            test.verifyTrue(isClass(outer));
        end

        function nonClassErrorsDoNotMatch(test)
            for id = ["MATLAB:load:couldNotReadFile", ...
                    "MATLAB:UndefinedFunction", "pk:boom", ...
                    "MATLAB:classX:foo", "MATLAB:ClassUstringX:foo", ...
                    "XMATLAB:class:foo"]
                test.verifyFalse(isClass(raise(id)), id);
            end
        end

        function nonClassCauseChainDoesNotMatch(test)
            outer = addCause(raise("MATLAB:load:couldNotReadFile"), ...
                raise("MATLAB:UndefinedFunction"));
            test.verifyFalse(isClass(outer));
        end

        function emptyIdentifierDoesNotMatch(test)
            test.verifyFalse(isClass(MException("", "no identifier")));
        end

    end
end

function e = raise(id)
    e = MException(id, "synthetic");
end

function tf = isClass(e)
    tf = prodserver.mcp.handler.internal.isClassSystemError(e);
end
