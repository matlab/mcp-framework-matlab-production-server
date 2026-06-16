classdef Primitive
% Primitive Types of objects forming the basis for client interaction.

% Copyright 2025, The MathWorks, Inc.

    enumeration
        Tool      % Callable functions
        Prompt    % Scripts for user interaction
        Resource  % Data accessible to client and server
        None      % None known. No information. Placeholder.
    end

    methods
        function name = mcpName(p)
            name = lower(string(p)+"s");
        end
    end
end