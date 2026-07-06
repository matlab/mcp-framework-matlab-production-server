function [sortedC,sortedS,areaC,areaS] = literalSchemas(circle,square)
% Sort circles and squares by area
    arguments(Input)
        % A vector of circles
        %#schema +circle.json
        circle (1,11) struct
        % A vector of squares
        %#schema +square.json
        square (1,13) struct
    end

    arguments(Output)
        % Vector of circles sorted by area.
        %#schema +circle.json
        sortedC (1,11) struct
        % Vector of squares sorted by area.
        %#schema +square.json
        sortedS (1,13) struct
        % Vector of circle areas
        areaC (1,11) double
        % Vector of square areas
        areaS (1,13) double
    end
    
    areaC = arrayfun(@(c)pi * c.radius * c.radius,circle);
    [areaC,I] = sort(areaC);
    sortedC = circle(I);

    areaS = arrayfun(@(s)s.side * s.side,square);
    [areaS,I] = sort(areaS);
    sortedS = square(I);

end

