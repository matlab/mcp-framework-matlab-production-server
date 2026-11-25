function y = toyByReferenceOutput(x)
%toyByReferenceOutput Test function whose only output is too large to
%return inline, so its wrapper returns it by reference, to a URL the caller
%may omit. Called without that URL, the tool returns nothing inline.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) double  % A scalar double.
    end
    arguments(Output)
        y (1,100) double  % 100 copies of the input.
    end

    y = repmat(x, 1, 100);

end
