function [n,extent,hero,area,cover] = toyZeroInputs()
% toyZeroInputs Return the side lengths and areas of N Heronian triangles 
% randomly chosen from the first 25. 
    arguments(Output)
        n double        % Heronian triangle number of each triangle, 1 to 25.
        extent (1,1) double % Total perimeter of all triangles
        hero struct     % Heronian triangle structure. Fields x, y and z.
        area double     % Area of each Heronian triangle.
        cover (1,1) double % Total area covered by all triangles
    end
   
    limit = 25;
    [hero,area] = heronian(limit);

    % How many triangles?
    n = randi(limit,1);
    % Which ones?
    n = randi(limit,1,n);

    hero = hero(n);
    area = area(n);

    extent = sum(arrayfun(@(t)t.x+t.y+t.z,hero));
    cover = sum(area);
end
