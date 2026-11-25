function [status,msg] = plotTrajectoriesMCP(quakeURL,sampleRate, ...
   correction,start,stop,plotURL)
%plotTrajectoriesMCP Generate a 3x3 plot of trajectories from 3-axis 
%seismometer data. Plot each axis against each other. On the diagonal place
%histograms of the data from each axis. 

% Copyright 2025-2026 The MathWorks, Inc.

    arguments (Input)
        % file: URL containing a table of uncorrected 3-axis seismometer accelerations
        quakeURL (1,1) string
        % Seismometer sample rate in Hertz
        sampleRate (1,1) double
        % Instrument correction: apply to quakeData
        correction (1,1) double
        % Start offset, in seconds, for trajectory data
        start (1,1) double
        % Stop offset, in seconds, for trajectory data
        stop (1,1) double
        % file: URL to save the plot into.
        plotURL (1,1) string
    end
    arguments (Output)
        status (1,1) logical   % True on success, false on error or failure.
        msg (1,1) string       % Non-empty error message if status is false.
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
