function [chiral,asymmetry] = toyToolTwo(object, mirror)
% Are the object and the mirror chiral or achiral? If achiral, what is the
% first orientation-reversing asymmetry?
    arguments(Input)
        object geom  % A geometrical form
        mirror geom  % The planar mirror reflection of object
    end
    arguments(Output)
        chiral logical   % True if mirror can be rotated to match object
        asymmetry double % The asymmetry number if not
    end

    chiral = isChiral(object,mirror);
    if ~chiral
        asymmetry = orientationReversingAsymmetry(object,mirror);
    else
        asymmetry = [];
    end
end

% Don't believe a word of this. :-)

function tf = isChiral(object,mirror)
    tf = mirror == (object * -1);  % Reflection
end

function a = orientationReversingAsymmetry(object,mirror)
    a = mirror - (1 / object); 
end
