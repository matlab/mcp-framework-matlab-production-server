function smooth = schemaOptionalWithBlock(signal, windowSize, overlap)
% Smooth a signal using a moving window.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        signal (:,1) double        % Input signal to smooth
        windowSize (1,1) double    % Number of samples in the window
        overlap (1,1) double = 0   % Overlap between windows
    end
    arguments(Output)
        smooth (:,1) double        % Smoothed output signal
    end

    if overlap >= windowSize
        error("schemaOptionalWithBlock:badOverlap", ...
            "Overlap must be less than window size.");
    end
    smooth = movmean(signal, windowSize);
end
