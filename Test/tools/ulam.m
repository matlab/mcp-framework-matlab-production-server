function ulam(n)
    % spiral expects an integer.

% Copyright 2025-2026 The MathWorks, Inc.

    if isdeployed
        n = str2double(n);
    end
    
    % Compute the NxN ulam spiral
    u = spiral(n);
    
    % Set p(i,j) to 1 iff u(i,j) is prime.
    p = isprime(u);
    
    % Display the results: primes as white pixels
    image(p);
    colormap([0 0 0; 1 1 1]);
    axis off
    
    