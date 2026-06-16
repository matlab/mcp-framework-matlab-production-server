function varargout = dragonGeometry(tdragon,properties)
% Compute geometric properties of the twin dragon fractal.

% Copyright 2025, The MathWorks, Inc.

    % tdragon must be an Nx2 matrix, where each row is (X,Y). So
    % tdragon(:,1) is all the Xs and tdragon(:,2) is all the Ys. Transpose
    % if size(2) > size(1).
    sz = size(tdragon);
    if sz(2) > sz(1)
        tdragon = tdragon';
    end

    % This big switch statement really should be separate functions. 

    % Extent of bounding box. Used by both "extent" and "dimension"
    min_x = min(tdragon(:,1));
    max_x = max(tdragon(:,1));
    min_y = min(tdragon(:,2));
    max_y = max(tdragon(:,2));

    % Origin, Width, Height
    extent = [min_x, min_y, max_x-min_x, max_y-min_y];
    
    varargout = cell(1,numel(properties));

    % Compute properties in the order in which they were requested.
    for n=1:numel(properties)
        switch properties(n)
            case "extent"
                varargout{n} = extent;

            case "centers"
                % Geometric center of the twin dragon.
                center = mean(tdragon);

                % If the distance between the dragon heads is normalized to
                % one, and the fractal is centered at (0,0), the center of
                % each dragon, in polar coordinates (r, theta), is:
                %
                % Dragon One: 2 ^ -(3/2), pi + (pi / 2) - sqrt(2) * pi
                % Dragon Two: 2 ^ -(3/2), (pi / 2) - sqrt(2) * pi
                % https://arxiv.org/html/2311.10102v2
                %
                % The point cloud generation algorithm results in a 
                % distance of 1.4142 between the heads of the Twin Dragon.

                rotation = pi / 4;

                % Scale R to match head distance.
                scale = 1.4142;
                r = 2 ^ -(3/2) * scale;

                a = (2 ^ -2);
                th1 = pi - (a * pi) + rotation;
                th2 = (pi * 2) - (a * pi) + rotation;

                % Convert to rectangular coordinates
                centers{1} = [r * cos(th1), r * sin(th1)];
                centers{2} = [r * cos(th2), r * sin(th2)];

                % Translate to account for non-zero origin.
                centers{1} = centers{1} + center;
                centers{2} = centers{2} + center;

                varargout{n} = centers;

            case "dimension"

                % Box counting density approximation

                % Shift the dragon into the first quadrant to simplify counting. This
                % places the lower left (min_x, min_y) coordinate of the bounding box
                % at the origin.
                tds(:,1) = tdragon(:,1) - min_x;
                tds(:,2) = tdragon(:,2) - min_y;
                boxes = 100:100:10000;
                count = zeros(1,numel(boxes));
                side = count;

                for nB = 1:numel(boxes)

                    d = configureDictionary("string","double");

                    % n x n grid of boxes over the shifted data (but we only need the
                    % width and height)
                    w = extent(3) / boxes(nB);
                    h = extent(4) / boxes(nB);
                    % Boxes must be square, so choose the larger of the two dimensions,
                    % to ensure the grid encompasses the entire fractal.
                    s = max(w,h);
                    side(nB) = s;

                    % Which box does each point fall into?

                    % Row of each point -- ( Y coordinate / height ) + 1
                    row = floor(tds(:,2) / s) + 1;

                    % Column of each point -- ( X coordinate / width ) + 1
                    col = floor(tds(:,1) / s) + 1;

                    % Each box is named row.col. Add one to the count for every point
                    % in a box.
                    for k = 1:numel(row)
                        box = sprintf("%d.%d",row(k),col(k));
                        if isKey(d,box)
                            d(box) = d(box) + 1;
                        else
                            d(box) = 1;
                        end
                    end

                    % Number of boxes required to "cover" fractal at level N - exactly
                    % those boxes that contain at least one point.
                    count(nB) = numEntries(d);
                end

                % Fractal dimension is the limit as side -> 0 of this function.
                % https://en.wikipedia.org/wiki/Minkowski-Bouligand_dimension
                y = log(count) ./ log(1./side);

                % Coefficients of line (Nth order polynomial) of best fit.
                N = 1;
                coeff = polyfit(1:numel(side),y,N);

                % Limit as X -> 0 of a continuous function is the Y intercept.
                dimension = polyval(coeff, 0);

                varargout{n} = dimension;

            otherwise
                error("Unrecognized geometrical property '%s'.", ...
                    properties(n));

        end

    end





end
