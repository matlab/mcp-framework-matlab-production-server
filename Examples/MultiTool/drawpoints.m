function drawpoints(xy,jpg,opts)
%drawpoints Produce a JPG image of a set of two-dimensional points.

    arguments(Input)
        xy double         % X and Y coordinates of the points
        jpg (1,1) string  % Path to file in which to save the JPG image

        % Color angle of each xy point, in degrees. Given an HSV color
        % wheel, this angle indicates the hue of the corresponding xy
        % point. The wheel is centered at the origin. The positive X axis
        % is zero degrees.
        opts.hue double
    end

    rgb = hueToRGB(opts.hue);

    f = figure(Visible='off');
    scatter(gca(f),xy(:,1), xy(:,2),0.1,rgb,'.');
    axis equal
    axis off
    saveas(f,jpg);
end

function rgb = hueToRGB(hue)

    rgb = zeros(numel(hue),3);

    % https://en.wikipedia.org/wiki/HSL_and_HSV

    % Saturation and Value
    S = 1;
    V = 1;

    % H specified in degrees
    n = [ 5, 3, 1 ];
    for i = 1:numel(n)
        k = mod(n(i) + (hue / 60), 6);
        % min of each row, so call using dimension argument.
        rgb(:,i) = V - (V * S * max(0,min([k,4-k,ones(size(k))],[],2)));
    end
end