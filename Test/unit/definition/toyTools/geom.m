classdef geom < double
% Fake little "geometry" class used for novel types in test examples.
    methods
        function g = geom(x)
            g = g@double(x);
        end
    end
end
