classdef RequireTestTools < matlab.unittest.fixtures.Fixture
%RequireTestTools Put the framework and one folder of test tools on the path.
%   The base of RequireToyTools, RequireSchemaTools and RequireParamTools,
%   which differ only in the folder under Test/tools.

% Copyright 2025-2026 The MathWorks, Inc.

    properties (SetAccess=immutable)
        toolFolder
        pkgFolder
    end

    methods

        function fix = RequireTestTools(subfolder)
            % Top-level folder that contains the +prodserver folder.
            fix.pkgFolder = prodserver.mcp.internal.packageFolder();

            % Location of the test tool functions.
            fix.toolFolder = fullfile(fix.pkgFolder, "Test", "tools", subfolder);
        end

        function setup(fix)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            fix.applyFixture(PathFixture(fix.pkgFolder));

            % Put the tool folder on the path.
            fix.applyFixture(PathFixture(fix.toolFolder));
        end
    end

    methods(Access=protected)

        function tf = isCompatible(fx1,fx2)
            % strcmp, not ==, which compares characters if a folder is char.
            tf = strcmp(fx1.toolFolder, fx2.toolFolder) && ...
                strcmp(fx1.pkgFolder, fx2.pkgFolder);
        end

    end

end
