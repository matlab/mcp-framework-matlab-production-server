function [cs,d] = toyScalarTwo(s,n)
%toyScalarTwo A test function that takes two scalars and returns two
%scalars. 

% Copyright 2026, The MathWorks, Inc.

    arguments(Input)
        s (1,1) string   % Input string
        n (1,1) double   % How many letters to capitalize
    end
    arguments(Output)
        cs (1,1) string   % Output string
        d (1,1) double   % Distance between first and last capital letter.
    end

    % Some excellent nonsense

    toCapital = randi(strlength(s), 1, n);

    % Round-trip through char.
    c = char(s);

    % Don't uppercase a space character
    space = find(c == ' ');
    adjust = ismember(toCapital,space);
    toCapital(adjust) = toCapital(adjust) + 1;

    % Apply uppercase at the chosen positions
    c(toCapital) = upper(c(toCapital));
    cs = string(c);
    d = max(toCapital) - min(toCapital);
end