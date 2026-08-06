function [reconstructed, gapMask] = interpolateWithMissing(t, signal, t_query, method)
% Interpolate a signal that contains NaN values marking sensor dropout.
%
% NaN values in the signal are treated as missing data points. The
% function interpolates through the gaps using valid samples only,
% reconstructing the signal at the requested query times.
%
% Without wire encoding, NaN is not a valid JSON literal. JSON null or 0
% would be substituted, causing the interpolation to fit through zero
% instead of bridging the gap — a dramatically different result.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        t (:,1) double                                          % Sample times
        signal (:,1) double                                     % Signal with NaN at dropouts
        t_query (:,1) double                                    % Query times for interpolation
        % Interpolation method ("linear", "pchip", "spline", or "makima")
        method (1,1) string {mustBeMember(method, ...
            ["linear","pchip","spline","makima"])} = "pchip"
    end
    arguments(Output)
        reconstructed (:,1) double   % Interpolated signal at query times
        gapMask (:,1) logical        % True where query falls in original gap
    end

    valid = ~isnan(signal);
    gapMask = interp1(t, double(~valid), t_query, 'nearest') > 0.5;
    reconstructed = interp1(t(valid), signal(valid), t_query, method);

end
