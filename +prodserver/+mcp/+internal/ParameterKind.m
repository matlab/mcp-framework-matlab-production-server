classdef ParameterKind
% Classify function parameters by relation to the parameter list.
% Note: order matters for Required, Optional and Repeating.

% Copyright 2026, The MathWorks, Inc.

    enumeration
        Required   % Required to appear in fixed location.
        Optional   % Optionally appear in fixed location.
        Repeating  % Optionally repeat following all positional parameters.
        NameValue  % Name=Value pairs. At the end of the argument list.
        Unknown    % Not yet known.
    end

    methods (Static)

        function [minArgs, maxArgs] = NargRange(pk)
            arguments
                pk prodserver.mcp.internal.ParameterKind
            end

            import prodserver.mcp.internal.ParameterKind
            count = ParameterKind.CountType(pk);
            minArgs = count(ParameterKind.Required);
            if count(ParameterKind.Repeating) > 0
                maxArgs = Inf;
            else
                maxArgs = minArgs + count(ParameterKind.Optional) + ...
                    (count(ParameterKind.NameValue)*2);
            end
        end

        function count = CountType(pk)
        % Count the number of each unique ParameterKind in the input pk.
            arguments
                pk prodserver.mcp.internal.ParameterKind
            end

            uK = enumeration(class(pk))';
            init = [num2cell(uK) ; num2cell(zeros(1,numel(uK)))];
            init = { init{:} }';
            count = dictionary(init{:});
            for n=1:numel(pk)
                count(pk(n)) = count(pk(n)) + 1;
            end
        end

        function pk = FromMetaData(required,identifier)
            import prodserver.mcp.internal.hasField
            import prodserver.mcp.internal.ParameterKind
            import prodserver.mcp.MCPConstants

            if required
                pk = ParameterKind.Required;
            else
                if hasField(identifier,MCPConstants.GroupName) && ...
                        strlength(identifier.(MCPConstants.GroupName)) > 0
                    pk = ParameterKind.NameValue;
                else
                    pk = ParameterKind.Optional;
                end
            end
        end
    end
end
