function y = schemaNoComments(windowSize, x, X, noisyURL, num_points, BBOX)
% Exercise generated parameter descriptions.

% Copyright 2026 The MathWorks, Inc.

    y = windowSize + x + X + strlength(noisyURL) + num_points + sum(BBOX);
end
