function [a,b,c] = toyToolDupNames(a,x,b,n)
    arguments(Input)
        % A collection of data
        a cell
        % Names of some things
        x string
        % Integer right triangle side lengths
        b struct
        % Max side length of triangles to add to b
        n (1,1) double
    end
    arguments(Output)
        % First among equals
        a (1,1) string
        % Expanded list of Heronian triangles
        b struct
        % Sum of triangle areas
        c (1,1) double
    end

    a = strjoin([a{1},x(end)]," ");
    b = [ b, heronian(n) ];
    c = sum(arrayfun(@(t)heroArea(t.x,t.y,t.z),b));
end

