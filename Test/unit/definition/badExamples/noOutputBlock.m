function [x,y] = noOutputBlock(a,b,c)
% This function has a beautiful, poetic description, and even an input
% arguments block. But its output arguments are undescribed. This file is
% badly formed.
    arguments
       a    % Input arguments
       b    % must have
       c    % descriptive comments.
    end

    x = a + b + c;
    y = a - b - c;
end
