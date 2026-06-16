function [the,answer] = missingInputDescription(life,universe,everything)
% Compute the answer to life, the universe and everything
    arguments(Input)
        life          % What we're doing
        universe      % Where we're doing it
        everything
    end
    arguments(Output)
        the           % What we'd like
        answer        % to know
    end
    the = life + universe;
    answer = everything;
end