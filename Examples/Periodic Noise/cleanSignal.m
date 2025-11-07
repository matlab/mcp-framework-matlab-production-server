function clean = cleanSignal(noisy,period)
%cleanSignal Remove periodic noise from a signal using a Butterworth notch
%filter.
    arguments (Input)
        % Noisy signal
        noisy double
        % period
        period (1,1) double
    end
    arguments (Output)
        % Filtered signal
        clean double
    end
    
    Fs = 1000;
    d = designfilt('bandstopiir','FilterOrder',2, ...
        'HalfPowerFrequency1',period-1, ...
        'HalfPowerFrequency2',period+1, ...
        'DesignMethod','butter','SampleRate',Fs);

    clean = filtfilt(d,noisy);
end