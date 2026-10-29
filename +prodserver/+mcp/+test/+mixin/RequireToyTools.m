classdef RequireToyTools < prodserver.mcp.test.mixin.RequireTestTools
%RequireToyTools Put the framework and Test/tools/toyTools on the path.

% Copyright 2025-2026 The MathWorks, Inc.

    methods
        function fix = RequireToyTools()
            fix@prodserver.mcp.test.mixin.RequireTestTools("toyTools");
        end
    end

end
