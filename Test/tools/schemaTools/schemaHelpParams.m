function [out, BBOX] = schemaHelpParams(signal, windowSize, N)
% Smooth a signal with a moving average.
% signal: samples to smooth
%   windowSize - window length,
%       in samples
% N: iterations. Higher numbers
%    smooth more.
% type: not a parameter
%
%   OUT - the smoothed signal
%   bbox: a bounding box

% Copyright 2026 The MathWorks, Inc.

    out = movmean(signal, windowSize) + 0*N;
    BBOX = [min(out), max(out)];
end
