function [disjointC,disjointS,removedC,removedS] = litAndExtSchemas(...
    circle,targetC,square,targetS)
% Remove the circles that intersect with circle(targetC) and the squares
% that intersect with square(targetS), where targetC and targetS are
% logical indices.

% Allow a varying number of circles but require a fixed number of squares.
% The circle-related variables will be externalized while the
% square-related variables should remain literal.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % A vector of circles of unlimited length.
        %#schema =circle.json
        circle struct
        % Test these circles for intersection with the other circles.
        targetC logical 
        % A vector of squares
        %#schema +square.json
        square (1,13) struct
        % Test these squares for intersection with the other squares
        targetS (1,13) logical
    end
    
    arguments(Output)
        % Circles that don't intersect any of the target circles.
        %#schema =circle.json
        disjointC struct
        % Squares that don't intersect any of the target squares.
        %#schema =square13.json
        disjointS struct
        % Logical index of circles that were removed from circle.
        removedC logical
        % Logical index of squares that were removed from square.
        removedS (1,13) logical
        
    end

    % Tag the circles that need removing.
    tc = circles(targetC);
    removedC = false(size(circle));
    for n = 1:numel(tc)
        for k = 1:numel(circle)
            if k == n
                continue;
            end

            if circles_intersect(tc)
                removedC(k) = true;
            end
        end
    end
    disjointC = circle(~removedC);

    % Tag the squares that need removing.
    ts = square(targetS);
    removedS = false(size(square));
    for n = 1:numel(ts)
        for k = 1:numel(square)
            if k == n
                continue;
            end

            if squares_intersect(ts)
                removedS(k) = true;
            end
        end
    end
    disjointS = square(~removedS);

end

function result = squares_intersect(s1, s2)
% Returns true if two axis-aligned squares intersect, false otherwise.
% Each square is a struct with fields:
%   origin  - struct with fields x, y (center of the square)
%   side    - scalar side length

    dx = abs(s2.origin.x - s1.origin.x);
    dy = abs(s2.origin.y - s1.origin.y);
    half_sum = (s1.side + s2.side) / 2;
    
    result = dx <= half_sum && dy <= half_sum;
end

function result = circles_intersect(c1, c2)
% Returns true if two circles intersect, false otherwise.
% Each circle is a struct with fields:
%   origin  - struct with fields x, y
%   radius  - scalar radius

    dx = c2.origin.x - c1.origin.x;S
    dy = c2.origin.y - c1.origin.y;
    d  = sqrt(dx^2 + dy^2);
    
    result = d <= (c1.radius + c2.radius) && d >= abs(c1.radius - c2.radius);
end