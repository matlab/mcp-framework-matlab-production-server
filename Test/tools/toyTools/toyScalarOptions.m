function report = toyScalarOptions(year, mpg, range, make, model)
% All inputs scalars, most optional. The comments in this file are bad
% examples of descriptive comments. They are mostly just lorem ipsum.
    arguments(Input)
        year (1,1) double   % The year of manufacture
        mpg (1,1) double = 3.49  % Known miles per gallon
        range (1,1) double = 4000  % Effective total range
        make (1,1) string = "Lockheed"  % Manufacturer name
        model (1,1) string = "Electra"  % Model name
    end
    arguments(Output)
        % A well formatted and informative message regarding the item in
        % question. Gripping reading. True literature.
        report (1,1) string 
    end

    report = sprintf("%s %s (%d) gets %.2f miles per gallon and has a range " + ...
            "of %d miles. Therefore it has a %.0f gallon tank.",...
                make, model, year, mpg, range, round(range ./ mpg));
end
