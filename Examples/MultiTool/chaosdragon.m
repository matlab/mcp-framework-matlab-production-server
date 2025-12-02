function dragon = chaosdragon(N)
% Generate N points of the twin-dragon fractal. 

    arguments(Input)
        N (1,1) double % Number of points in the resulting fractal.
    end
    arguments (Output)
        % Nx2 matrix of fractal points. Each row is a single point. Column 1
        % is the X coordinates, column 2 the Y coordinates.
        dragon double  
    end

    % Two affine transformations
    A = [0.5, -0.5; 0.5, 0.5];

    % Generate a random initial 2D point in the range [0, 1]
    x = rand(1, 2)';
    
    dragon = zeros(2,N*2);
    for n = 1:2:N*2-1
        dragon(:,n) = A * x;
        dragon(:,n+1) = dragon(:,n) + [1;0];
        if rand(1) > 0.5
            x = dragon(:,n);
        else
            x = dragon(:,n+1);
        end
    end

end
    
   