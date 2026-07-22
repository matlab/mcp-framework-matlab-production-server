classdef RequireToyTools < matlab.unittest.fixtures.Fixture

    properties (SetAccess=immutable)
        toolFolder
        pkgFolder
    end

    methods 

        function fix = RequireToyTools()
            
            % Top-level folder that contains the +prodserver folder.
            fix.pkgFolder = fullfile(fileparts(mfilename("fullpath")),...
                "../../../..");

            % Location of the MCP tool functions used in the tests
            fix.toolFolder = fullfile(fix.pkgFolder, "Test", ...
                "tools","toyTools");
        end

        function setup(fix)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            fix.applyFixture(PathFixture(fix.pkgFolder));
    
            % Put the toyTools folder on the path.
            fix.applyFixture(PathFixture(fix.toolFolder));
        end
    end
        
    methods(Access=protected)

        function tf = isCompatible(fx1,fx2)
            tf = (fx1.toolFolder == fx2.toolFolder) && ...
                (fx1.pkgFolder == fx2.pkgFolder);
        end

    end

end
