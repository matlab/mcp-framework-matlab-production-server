function [status,msg] = plotTrajectoriesMCP(quakeURL,sampleRate, ...
    correction,start,stop,plotURL)
%plotTrajectoriesMCP Generate a 3x3 plot of trajectories from 3-axis 
%seismometer data. Plot each axis against each other. On the diagonal place
%histograms of the data from each axis. 
    arguments (Input)
        % file: URL containing a table of uncorrected 3-axis seismometer accelerations
        quakeURL string
        % Seismometer sample rate in Hertz
        sampleRate double
        % Instrument correction: apply to quakeData
        correction double
        % Start offset, in seconds, for trajectory data
        start double
         % Stop offset, in seconds, for trajectory data
        stop double
        % file: URL to save the plot into.
        plotURL string
    end
    arguments (Output)
        status logical   % True on success, false on error or failure.
        msg string       % Non-empty error message if status is false.
    end

    status = true;
    msg = 'OK';
    try
        quakeFile = prodserver.mcp.io.uri.File.FileURI2Path(quakeURL);
        qd = readtable(quakeFile);
        plotFile = prodserver.mcp.io.uri.File.FileURI2Path(plotURL);
        plotTrajectories(qd,sampleRate,correction,start,stop,plotFile);
    catch ex
        status = false;
        msg = ex.message;
    end
end
