function [z,u,m] = optInExtOut(q,v,opts)
% Mix optional inputs with externalized outputs. Both become optional
% inputs in the wrapper function. Used to verify that opts and out groups
% appear in the right order and that optional inputs are properly
% associated with their comments.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        % Required scalar Q
        q (1,1) string
        % Required vector V
        v (1,17) double
        % Polar coordinates of something mysterious
        %#schema =polarCoords.json
        opts.p struct 
        % Does the input array contain this value?
        %#schema =polarCoords.json
        opts.t struct
    end
    arguments (Output)
        % A string array formed by adding q and v.
        z string
        % The number of characters in z.
        u (1,1) double
        % A vector of polar points consisting of those points in opts.t 
        % that are also in opts.t.
        %#schema =polarCoords.json
        m struct
    end

    % Absolute nonsense. Adding numbers and strings and computing the
    % number of characters in the resulting string array.
    z = q + v;
    u = sum(strlength(z));

    % Now look for opts.t in opts.p. 
    m.r = NaN;
    m.theta = NaN;
    if ~isempty(opts.p) && ~isempty(opts.t)
        for nt = 1:numel(opts.t)
            for np=1:numel(opts.p)
                if isequal(opts.p(np),opts.t(nt))
                    m(nt).r = opts.p(np).r;
                    m(nt).theta = opts.p(np).theta;
                end
            end
        end
    end
end