function [the,answer] = missingOutputDescription(life,universe,everything)
% Compute the answer to life, the universe and everything
    arguments(Input)
        life          % What we're doing
        universe      % Where we're doing it
        everything    % What everyone else is doing
    end
    arguments(Output)
        the           % What we'd like
        answer        
    end
    the = life + universe;
    answer = everything;
end