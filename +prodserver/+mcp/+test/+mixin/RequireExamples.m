classdef RequireExamples < matlab.unittest.fixtures.Fixture

    properties (SetAccess=immutable)
        pkgFolder
        exampleFolder
    end

    methods 

        function fix = RequireExamples()
        % Put all the example folders on the path
        
            import matlab.unittest.fixtures.PathFixture

            % Top-level folder that contains the +prodserver folder.
            fix.pkgFolder = fullfile(fileparts(mfilename("fullpath")),...
                "../../../..");

            % Location of the MCP tool functions used in the tests
            fix.exampleFolder = fullfile(fix.pkgFolder,"Examples");
        end

        function setup(fix)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            fix.applyFixture(PathFixture(fix.pkgFolder));
    
            % Put the example folders on the path
            earthquakeFolder = fullfile(fix.exampleFolder,"Earthquake");
            fix.applyFixture(PathFixture(earthquakeFolder));

            primeFolder = fullfile(fix.exampleFolder,"Primes");
            fix.applyFixture(PathFixture(primeFolder));
        end
    end
        
    methods(Access=protected)

        function tf = isCompatible(fx1,fx2)
            tf = (fx1.toolFolder == fx2.toolFolder) && ...
                (fx1.pkgFolder == fx2.pkgFolder);
        end

    end

end
