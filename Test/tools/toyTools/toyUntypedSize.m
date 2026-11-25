function y = toyUntypedSize(x)
%toyUntypedSize Test function whose input has a declared size but no
%declared class, so nothing but an example says what class it is.

% Copyright 2026 The MathWorks, Inc.

    arguments (Input)
        x (1,:)  % A row of values of any class.
    end
    arguments (Output)
        y (1,:)  % The input.
    end

    y = x;

end
