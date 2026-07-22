classdef SchemaInjection
% SchemaInjection How to merge user-specified schema data with the
% automatically generated schema.

% Copyright 2026, The MathWorks, Inc.

    enumeration
        % Add new properties to the schema. Error if the properties exist.
        Add    

        % Replace existing properties in the schema. DO NOT ERROR based on
        % the existence or non-existence of the properties.
        Replace  

        % Who knows? (Out of band value for initialization, etc.)
        Unknown
    end

    % Static functions instead of properties to allow access without
    % creating an instance of the SchemaInjection class.
    methods(Static)
        function token = AddToken()
            token = "+";
        end

        function token = ReplaceToken()
            token = "=";
        end
    end
end
        