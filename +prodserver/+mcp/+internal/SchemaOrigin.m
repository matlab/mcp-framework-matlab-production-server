classdef SchemaOrigin
% SchemaOrigin What process generated the schema?

    enumeration
        Introspection   % Automatic introspection of the MATLAB function.
        Client          % The client specified the entire schema.
        Hybrid          % Partially automatic; some properties from client.
        Unknown         % When there's no schema, usually.
    end

end
