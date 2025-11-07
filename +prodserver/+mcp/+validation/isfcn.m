function tf = isfcn(x, mustExist)
% isfcn The input is a function if it is the name of a function on the path
% or an actual function handle.

% Copyright 2025, The MathWorks, Inc.

    if nargin == 1
        mustExist = false;
    end

    tf = false(size(x));
    for n = 1:numel(x)
        if prodserver.mcp.validation.istext(x)
            tf(n) = true;
            parts = split(x(n),".");
            for p = parts'
                tf(n) = tf(n) && isvarname(p);
            end
        else
            % Function handles cannot be vectors because they overload ()
            tf = isa(x,"function_handle");
            if tf && mustExist
                x = string(func2str(x));  % So x(n) in which works.
            end
        end

        if tf(n) && mustExist
            % Anonymous functions always exist -- and their string
            % representation always starts with "@".
            if startsWith(x(n),"@") == false
                tf(n) = ~isempty(which(x(n)));
            end
        end
    end
end
