classdef RequireParamTools < prodserver.mcp.test.mixin.RequireTestTools
%RequireParamTools Put the framework and Test/tools/parameterTools on the path.

% Copyright 2025-2026 The MathWorks, Inc.

    methods
        function fix = RequireParamTools()
            fix@prodserver.mcp.test.mixin.RequireTestTools("parameterTools");
        end
    end

end
