function list = fixedSizeVectors(circle,square,area)
% fixedSizeVectors Choose (select) the input geometric objects that have an
% area less than the given area input. Use fixed size vectors for the lists
% of geometric objects.

% Copyright 2026, The MathWorks, Inc.

    arguments(Input)
        % List of circles
        %#schema =circle.json
        circle (1,11) struct
        % List of squares
        %#schema =square.json
        square (1,7) struct
        % Area limit -- select all circles and squares smaller than this.
        area double
    end
    arguments(Output)
        % Selected circles and squares that are smaller than the given
        % input area.
        %#schema +{"maxItems": 20}
        list cell
    end

    circleArea = arrayfun(@(c)pi * c.radius * c.radius,circle);
    squareArea = arrayfun(@(s)s.side * s.side,square);
    list = [ num2cell(circle(circleArea < area)), ...
        num2cell(square(squareArea < area)) ];
end
