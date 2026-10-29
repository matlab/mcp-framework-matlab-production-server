function tf = isClientMistake(me)
%isClientMistake True for exceptions that blame the caller, not the server.
%   An unknown tool, an unknown or ambiguous resource URI, arguments that do
%   not match the declared schema: the server worked correctly and the request
%   was wrong. Both specs' worked example for this is
%   {"code": -32602, "message": "Unknown tool: invalid_tool_name"}, so reporting
%   any of them as an internal error contradicts the published shape.
%
%   Protocol-neutral on purpose. Which of our identifiers describe a caller's
%   mistake is a fact about this framework's error vocabulary, not about any
%   revision of the spec; what each revision then makes of that -- the code and
%   the HTTP status -- is the business of its own mapErrorCode. Keeping the
%   classification here is what stops a seventh identifier from being added to
%   one revision's mapper and not the other's, which would show up only as a
%   500 on one protocol and a -32602 on the other. The enumeration itself is
%   clientMistakes, kept separate so the tests can iterate it rather than
%   maintain a second copy.
%
%   ResourceNotFound is deliberately absent even though it is plainly a
%   caller's mistake: the two revisions disagree about it. 2025-06-18 has a
%   dedicated -32002 for it and 2026-07-28 MUST NOT emit that code, having
%   folded the case into Invalid Params. Each mapper settles it separately.

% Copyright 2026 The MathWorks, Inc.

    tf = any(startsWith(string(me.identifier), ...
        prodserver.mcp.protocol.clientMistakes()));
end
