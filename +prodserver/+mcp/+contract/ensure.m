function ensure(condition, clause)
%ensure Raise a contract violation unless CONDITION holds.
%
%   prodserver.mcp.contract.ensure(CONDITION, CLAUSE) does nothing when
%   CONDITION is true. Otherwise it raises
%   prodserver:mcp:internal:ContractViolation, whose message names CLAUSE.
%   Call it only inside an enforce guard, so CONDITION is evaluated only
%   when checking is on. What a client sees when a violation escapes is the
%   error contract of the code that called it.
%
%   See also prodserver.mcp.contract.enforce

% Copyright 2026 The MathWorks, Inc.

% Contract:
%   Kind:      query (no side effect unless it raises)
%   Requires:  condition is a logical scalar   (arguments: logical (1,1))
%              clause names the contract line  (arguments: mustBeNonzeroLengthText)
%   Ensures:   returns only when condition is true
%   Raises:    none  (a failed condition raises prodserver:mcp:internal:ContractViolation, a framework defect)

    arguments
        condition (1,1) logical
        clause (1,1) string {mustBeNonzeroLengthText}
    end
    if ~condition
        throwAsCaller(MException("prodserver:mcp:internal:ContractViolation", ...
            "Contract violated: %s", clause));
    end
end
