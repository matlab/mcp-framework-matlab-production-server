function report = toyURLOptions(ngc, ra, dec, opts)
% Format deep sky object data into a tabular report.
    arguments(Input)
        ngc string   % New General Catalog number
        ra  double   % Right ascension
        dec double   % Declination
        % Appears in this constellation
        opts.constellation string = string.empty 
        opts.messier string = string.empty      % Messier catalog number 
        opts.name string = string.empty         % Common name
    end
    arguments(Output)
        % A (literally) stellar account. Over our heads and out of this
        % world.
        report (1,1) string
    end
    
    starChart = table(ngc,ra,dec,VariableNames=["NGC", "R.A.", "Dec."]);
    if ~isempty(opts.constellation)
        starChart = addvars(starChart,opts.constellation,NewVariableNames="Constellation");
    end
    if ~isempty(opts.messier)
        starChart = addvars(starChart,opts.messier,NewVariableNames="Messier");

    end
    if ~isempty(opts.name)
        starChart = addvars(starChart,opts.name,NewVariableNames="Name");
    end

    report = formattedDisplayText(starChart);
end
