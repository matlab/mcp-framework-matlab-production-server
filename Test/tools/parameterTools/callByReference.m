function tf = callByReference(c1,c2)
% Do any of the circles in c1 and c2 intersect?
% 
% Test of the x-call-by: reference schema extension, which should force
% c1 to be an externalized rather than a literal variable.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments (Input)
        % A vector of circles
        %#schema =circleByReference.json
        c1 (1,17) struct

        % A vector of circles
        %#schema =circle.json
        c2 (1,17) struct
    end
    arguments (Output)
        % A MxN matrix of logical values. tf(M,N) == true if
        % c1(M) intersects c2(N).
        tf logical
    end

    tf(numel(c1),numel(c2)) = false;
    for n = 1:numel(c1)
        for k = 1:numel(c2)

            tf(n,k) = false; % Initialize intersection flag
            % Compute the distance between the two circles
            distance = sqrt((c1(n).center.x - c2(k).center.x)^2 + ...
                (c1(n).center.y - c2(k).center.y)^2);

            % If the distance is less than the sum of the radii, they
            % intersect.
            if c1(n).radius + c2(k).radius >= distance
                tf(n,k) = true; % Set flag if circles intersect
            end
        end
    end
end

