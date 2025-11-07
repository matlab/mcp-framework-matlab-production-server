function [x,y,z] = toyToolOne(a,b)
% First of the toy tools which do nothing useful.
    arguments(Input)
        a (1,1) double % A scalar, as if the declaration wasn't obvious
        b uint64       % Who knows how big this could get?
    end
    arguments(Output)
        x    % A powerful result
        y    % Power augmented by 2^8!
        z    % Not quite so much
    end

    x = b .^ a;
    y = x + 64;
    z = b - a;
end
