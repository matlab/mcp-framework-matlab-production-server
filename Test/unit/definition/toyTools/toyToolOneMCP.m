function [x,y,z] = toyToolOneMCP(a,b)
% First of the toy tools which do nothing useful.
    arguments(Input)
        a (1,1) double % A scalar, as if the declaration wasn't obvious
        b string { prodserver.mcp.validation.mustBeURI }  % Who knows how big this could get?
    end
    arguments(Output)
        x    % A powerful result
        y    % Power augmented by 2^8!
        z    % Not quite so much
    end
    b = deserialize(b);
    [x,y,z] = toyToolOne(a,b);
end