function clean = cleanSignal(noisy,frequency)
%cleanSignal Remove periodic noise from a signal using a Butterworth notch
%filter.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments (Input)
        % Noisy signal
        noisy double
        % Noise frequency to remove, in Hz (e.g. 60 for mains hum).
        % Between 1 and 499 Hz: the filter's stop band is 2 Hz wide and
        % must fit below half the 1000 Hz sample rate.
        %#schema { "exclusiveMinimum": 1, "exclusiveMaximum": 499 }
        frequency (1,1) double {mustBeGreaterThan(frequency,1), mustBeLessThan(frequency,499)}
    end
    arguments (Output)
        % Filtered signal
        clean double
    end
    
    Fs = 1000;
    d = designfilt('bandstopiir','FilterOrder',2, ...
        'HalfPowerFrequency1',frequency-1, ...
        'HalfPowerFrequency2',frequency+1, ...
        'DesignMethod','butter','SampleRate',Fs);

    clean = filtfilt(d,noisy);
end