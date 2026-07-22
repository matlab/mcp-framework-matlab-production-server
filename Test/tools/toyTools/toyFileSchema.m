function [z,q] = toyFileSchema(m,r)
    arguments(Input)
        % Increase the size of each side of each triangle by this amount.
        m (1,1) double
        % An array of triangles.
        %#schema =triangle.json
        r struct
    end
    arguments(Output)
        % The new triangles, after adding m to each side.
        %#schema =triangle.json
        z 
        % Area of each of the new triangles
        %#schema +{ "maxItems": 39 }
        q (1,:) double
    end

    % Allocate result
    init = num2cell(zeros(size(r)));
    z = struct('x', init, 'y', init, 'z', init);
    q = zeros(1,numel(r));

    % Calculate the new triangle dimensions
    for n = 1:numel(r)
        z(n).x = r(n).x + m;
        z(n).y = r(n).y + m;
        z(n).z = r(n).z + m;
    
        % Calculate the area of the new triangle using Heron's formula
        s = (z(n).x + z(n).y + z(n).z) / 2; % semi-perimeter
        q(n) = sqrt(s * (s - z(n).x) * (s - z(n).y) * (s - z(n).z));
    end
end