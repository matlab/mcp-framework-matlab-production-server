function tf = circlesIntersect(c1, c2)
% Do any of the circles in c1 and c2 intersect?
    arguments (Input)
        % A vector of circles
        %#schema =circle.json
        c1 (1,:) struct 

        % A vector of circles
        %#schema =circle.json
        c2 (1,:) struct
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
            distance = sqrt((c1(n).origin.x - c2(k).origin.x)^2 + ...
                (c1(n).origin.y - c2(k).origin.y)^2);

            % If the distance is less than the sum of the radii, they
            % intersect.
            if c1(n).radius + c2(k).radius >= distance
                tf(n,k) = true; % Set flag if circles intersect
            end
        end
    end
end
