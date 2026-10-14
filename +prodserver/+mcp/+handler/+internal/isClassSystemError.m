function tf = isClassSystemError(err)
%isClassSystemError True if ERR, or any error in its cause chain, came from
%   the MATLAB class system.
%
%   toolServices uses this to tell an archive whose class definitions clash
%   with another archive's -- the multi-MCOS problem, which only a server
%   restart can fix -- from a definition file that is simply unreadable.
%
%   The test is on the identifier's catalog prefix, not on a list of exact
%   identifiers, because the exact ones are not stable enough to match:
%     * Several class-system messages live in the ClassUstring catalog, so
%       their identifiers are MATLAB:ClassUstring:*, not the MATLAB:class:*
%       their message text suggests.
%     * An error raised while defining an enumeration member is rethrown
%       under the INNER error's identifier, with no cause, so no fixed
%       identifier names it.
%     * A failed conversion during load raises the generic
%       MATLAB:class:CannotConvert or MATLAB:class:InvalidEnum.
%   The prefix comparison includes the trailing colon, so a catalog that
%   merely begins with "class" (MATLAB:classX:*) does not match.

% Copyright 2026 The MathWorks, Inc.

    arguments
        err MException
    end

    tf = startsWith(string(err.identifier), ...
        ["MATLAB:class:", "MATLAB:ClassUstring:"]);
    for k = 1:numel(err.cause)
        if tf
            return
        end
        tf = prodserver.mcp.handler.internal.isClassSystemError(err.cause{k});
    end
end
