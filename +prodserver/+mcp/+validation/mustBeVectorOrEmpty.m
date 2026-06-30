function mustBeVectorOrEmpty(A)
% mustBeVectorOrEmpty Error if A fails isvector and isempty.

% Copyright 2026 The MathWorks, Inc.

if ~isvector(A) && ~isempty(A)
    throwAsCaller(MException(message("MATLAB:validators:mustBeVectorOrEmpty")));
end