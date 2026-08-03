classdef SchemaOrigin
% SchemaOrigin What process generated the schema?

% Copyright 2025-2026 The MathWorks, Inc.

    enumeration
        Introspection   % Automatic introspection of the MATLAB function.
        Client          % The client specified the entire schema.
        Hybrid          % Partially automatic; some properties from client.
        Unknown         % When there's no schema, usually.
    end

end
