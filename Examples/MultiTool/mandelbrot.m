function m=mandelbrot(width, iterations)
% MANDELBROT Generate Mandelbrot set with WIDTH pixels on the X axis. Uses
% the Escape Time algorithm to determine the color of each point in the
% fractal.
%
% Algorithms based on the Wikipedia article:
% http://en.wikipedia.org/wiki/Mandelbrot_set

    arguments(Input)
        width (1,1) double      % X-axis width of the Mandelbrot set.
        iterations (1,1) double % Number of iterations used to create the fractal.
    end
    arguments(Output)
        % The colors of the points of the Mandelbrot set. Five-dimensional
        % matrix: [X, Y, R, G, B].
        m double 
    end

    % Height is the even number >= two-thirds of the width
    height = floor(width * 2.5 / 3);
    if mod(height, 2) ~= 0, height = height + 1; end
    
    m = zeros(height, width, 3);
    
    col = 1;
    
    % Compute the values of the Mandelbrot set using the popular
    % "Escape Time" algorithm. Each color in the image represents the
    % number of steps required for the iterative series to diverge to
    % infinity. The color black means the series never diverged. The black
    % pixels represent the points in the Mandelbrot set. See the Wikipedia
    % article for much more detail:
    %
    % http://en.wikipedia.org/wiki/Mandelbrot_set
    %
    % The Mandelbrot set has real (x) coordinate from -2 to +1, and
    % imaginary coordinate from -1.5 to +1.5. Since the set is perfectly
    % symmetrical about the X axis, we compute half the data (the
    % negative imaginary plane, Y from -1.5 to 0) and then mirror it to
    % produce the final image.
    for xp = -2.2:3.2/width:1
        row = 1;
        % Compute escape time for the negative imaginary values.
        for yp = -1.25:2.5/height:0 % Mirror around X-axis
            
            k = 0;
            x = 0;
            y = 0;
            
            % Optimization: check to see if the point can be
            % deterministically shown to be in the cardioid or the bulb.
            p = sqrt((xp-.25)^2 + yp^2);
            if ((xp < (p - (2*p^2) + 0.25)) || ...
                (xp+1)^2 + yp^2 < (1/16))
                k = iterations;
            end
            
            % Iterate: determine if the series converges to C (here 2) or
            % diverges to infinity.
            while ( k < iterations && x*x + y*y <= (2*2))
                [k, x, y] = iterate(k, x, y, xp, yp);
            end
            % If the series diverged, color the pixel according to the
            % number of steps required for divergence. Otherwise, it
            % converged, so color the pixel black.
            if k < iterations
                m(row, col, :) = iterationColor(k, x, y, xp, yp, iterations);
            end
            row = row + 1;
        end
        col = col + 1;
    end
    
    % Mirror the negative imaginary values into the positive half-plane.
    m(row-1:height, :, :) = m(row-2:-1:1, :, :);
    % Convert color data from HSV to RGB. I used HSV because it's easier to
    % navigate, but MATLAB's image command expects RGB colors.
    m = hsv2rgb(m);
    m = uint8(floor(m * 255));
end

function [k, x, y] = iterate(k, x, y, xp, yp)
% ITERATE Solve one iterative step of the equation (Z(n) = Z(n-1)^2 + C).
    xt = x*x - y*y + xp;
    y = 2*x*y + yp;
    x = xt;
    k = k + 1;    
end

function hsv = iterationColor(k, x, y, xp, yp, iterations)
% ITERATIONCOLOR Smoothly interpolate pixel color based on escape count.

    % Iterate three more times to reduce error term.
    for l = 1:3
        [k, x, y] = iterate(k, x, y, xp, yp);
    end
    % Normalize count by taking the log log of norm of Z
    c = normalizeCount(k, x, y);
    % Interpolate the color around the top of the HSV cone. Start at clr
    % degrees. Wrap around using MOD. Set S (saturation) and V (value) to 
    % 1 for bright colors. CLR = 2/3 to start at blue, 1/2 to start at
    % red.
    clr = (1/2);
    hsv = [mod((c / iterations) + clr, 1) 1 1];
end

function nC = normalizeCount(k, x, y)
% NORMALIZECOUNT Fractional iteration count for smooth color interpolation.

    % Take the log log of the norm of Z: log(log(|Z(n)|))
    nC = k + 1 - log(log(sqrt(x*x+y*y))) / log(2);
end

