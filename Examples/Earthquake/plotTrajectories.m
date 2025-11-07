function plotTrajectories(quakeData,sampleRate,correction,start,stop,plotFile)
%plotTrajectories Generate a 3x3 plot of trajectories from 3-axis 
%seismometer data. Plot each axis against each other. On the diagonal place
%histograms of the data from each axis.
    arguments
        quakeData   % Table of uncorrected 3-axis seismometer accelerations
        sampleRate  % Seismometer sample rate in Hertz
        correction  % Instrument correction: apply to quakeData
        start       % Start offset, in seconds, for trajectory data
        stop        % Stop offset, in seconds, for trajectory data
        plotFile    % Name of the file to save the plot into
    end

    % Make a timetable from the quake data by adding a column of fractional
    % seconds based on the sample rate.
    Time = (1/sampleRate)*seconds(1:height(quakeData))';
    varNames = ["EastWest","NorthSouth","Vertical"];
    qd = timetable(Time,quakeData.e,quakeData.n,quakeData.v, ...
        VariableNames=varNames);

    % Correct the data to acceleration in g, using instrument correction
    % factor.
    qd.Variables = correction*qd.Variables;

    % Select start -> stop interval
    start = seconds(start);
    stop = seconds(stop);
    tr = timerange(start,stop);
    qdInterval = qd(tr,:);

    % Compute velocity by integrating acceleration. Keep original variable
    % names.
    integrator = @(x)velFun(x,sampleRate);
    velocity = varfun(integrator,qdInterval);
    velocity.Properties.VariableNames = varNames;

    % Compute position by integrating velocity. Keep original variable
    % names.
    position = varfun(integrator,velocity);
    position.Properties.VariableNames = varNames;

    % 3x3 grid of plots of sensor motion: East-West, North-South and 
    % Vertical plotted against each other, with histograms of each sensor's
    % motion along the diagonal.

    f=figure(Visible="off");
    [~,Ax] = plotmatrix(position.Variables);
    
    for ii = 1:length(varNames)
        xlabel(Ax(end,ii),varNames{ii})
        ylabel(Ax(ii,1),varNames{ii})
    end
    saveas(f,plotFile);
end

function y = velFun(x,hz)
    y = (1/hz)*cumsum(x);
    y = y - mean(y);
end