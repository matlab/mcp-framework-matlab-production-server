function y = toyRecordInput(x)
%toyRecordInput Test function that keeps the value it was called with, in
%appdata toyRecordInput, so a test can check what an example passed it.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x double  % Any double, real or complex.
    end
    arguments(Output)
        y double  % The input.
    end

    setappdata(0, "toyRecordInput", x);
    y = x;

end
