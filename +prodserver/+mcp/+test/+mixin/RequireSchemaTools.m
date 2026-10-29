classdef RequireSchemaTools < prodserver.mcp.test.mixin.RequireTestTools
%RequireSchemaTools Put the framework and Test/tools/schemaTools on the path.

% Copyright 2026 The MathWorks, Inc.

    methods
        function fix = RequireSchemaTools()
            fix@prodserver.mcp.test.mixin.RequireTestTools("schemaTools");
        end
    end

end
