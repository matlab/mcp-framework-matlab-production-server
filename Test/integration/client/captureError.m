function err = captureError(fcn,n)
%captureError Invoke FCN asking for N outputs; return the MException it raised.
%   Empty if it raised none. N may be 0, for a call made as a statement.
%   nargout is part of the contract under test, and an anonymous handle
%   invoked by verifyError is called with nargout 0, so the count has to be
%   set here rather than left to the framework.
%
%   Shared by the client suites in this folder, beside MockCaller.

% Copyright 2026 The MathWorks, Inc.

    err = MException.empty;
    try
        if n == 0
            fcn();
        else
            out = cell(1,n);
            [out{1:n}] = fcn(); %#ok<NASGU> the outputs are not what is under test
        end
    catch err
    end
end
