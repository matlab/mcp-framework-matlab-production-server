function answer = toySummary(data)
% Add the contents of the input files in DATA, producing ANSWER. DATA is 
% a list of loadable files.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % The list of data files
        data string {mustBeVector}
    end
    arguments(Output)
        % The sum of the contents of the two data files.
        answer double
    end

    answer = 0;
    for n = 1:numel(data)
        d = load(data(n));
        answer = answer + d.content;
    end
end