function result = apply(fcn,list,varargin)
% apply Apply a function to a list of items. Optional input uniform
% indicates if all results are expected to the the same type.

% Copyright 2025, The MathWorks, Inc.

    % All these booleans may be a style violation, but they certainly are
    % convenient.
    ip = inputParser;
    addParameter(ip,"Flatten",false,@islogical);
    addParameter(ip,"Uniform",false,@islogical);
    addParameter(ip,"Recurse",false,@islogical);
    addParameter(ip,"Skip",@(x)false,@(p)isa(p,"function_handle"));
    parse(ip,varargin{:});
    
    if ip.Results.Recurse
        result = recurse(fcn,list,ip.Results.Skip);
    elseif iscell(list)
        result = cellfun(fcn,list,UniformOutput=ip.Results.Uniform);      
    else
        result = arrayfcn(fcn,list,UniformOutput=ip.Results.Uniform);
    end
    if ip.Results.Flatten
        result = [ result{:} ];
    end
end

function x = recurse(fcn, x, skip)
%recurse Apply fcn to every value in x, which may be a MATLAB container.
    
    if isstruct(x) && ~skip(x)
        if numel(x) > 1
            % Iterate over non-scalar struct arrays.
            for n = 1:numel(x)
                x(n) = recurse(fcn, x(n), skip);
            end
        else
            % Apply function to each field of a scalar struct.
            for f = string(fieldnames(x)')
                x.(f) = recurse(fcn, x.(f), skip);
            end
        end
    elseif iscell(x) && ~skip(x)
        x = cellfun(@(e)recurse(fcn,e,skip),x,UniformOutput=false);
    elseif (isa(x,"dictionary") || isa(x, "containers.Map")) && ~skip(x)
        ks = keys(x); 
        if iscolumn(ks), ks = ks'; end
        for k = ks
            x(k) = recurse(fcn,x(k),skip);
        end
    else
        x = feval(fcn,x);
    end
end

