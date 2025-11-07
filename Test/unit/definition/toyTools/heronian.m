function [hero,area] = heronian(N)
% heronian Generate unique Heronian triangles with sides <= N

% Copyright 2025, The MathWorks, Inc.

    hero = struct.empty;
    area = double.empty;
    sidesByArea = configureDictionary('double','cell');
    for x=1:N
        for y=1:N
            for z=1:N
                % Triangle inequality -- x,y,z don't make a
                % triangle unless the shortest side is less than
                % the sum of the other two sides.
                sides = sort([x,y,z]);
                if sides(1) > sides(2) + sides(3)
                    continue;
                end
    
                % Test for integer area using Hero's formula
                a = heroArea(x,y,z);
                if a > 0 && (a - floor(a)) < eps && novel(a,sides,sidesByArea)
                    n = numel(hero) + 1;
                    hero(n).x = x;
                    hero(n).y = y;
                    hero(n).z = z;
                    area(n) = a;
                    if isKey(sidesByArea,a)
                        s = sidesByArea(a); s = s{1};
                        sidesByArea(a) = { [s; sides] };
                    else
                        sidesByArea(a) = { sides };
                    end
                    if n == N
                        return;
                    end
                end
            end
        end
    end
end

function tf = novel(a,sides,sidesByArea)
    tf = true;
    if isKey(sidesByArea,a)
        s = sidesByArea(a); s = s{1};
        % Look for the triple of sides in the list of known
        % sides.
        tf = ismember(sides,s,"rows");
        % sides is a novel triangle only if it matched no known sides.
        tf = nnz(tf) == 0;
    end
end
