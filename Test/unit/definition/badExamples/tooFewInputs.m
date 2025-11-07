function [the,answer] = tooFewInputs(life,universe,everything)
% Compute the answer to life, the universe and everything
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