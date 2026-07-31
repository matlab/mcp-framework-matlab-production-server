function [the,answer] = tooFewInputs(life,universe,everything)
% Compute the answer to life, the universe and everything

% Copyright 2025-2026 The MathWorks, Inc.

    arguments(Input)
        life
        universe
        everything
    end
    arguments(Output)
        the
        answer
    end
    the = life + universe;
    answer = everything;
end