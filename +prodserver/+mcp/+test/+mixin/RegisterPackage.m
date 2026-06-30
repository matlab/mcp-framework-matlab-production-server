classdef RegisterPackage < matlab.unittest.fixtures.Fixture
% Make sure the prodserver package is on the path.

% Copyright 2026, The MathWorks, Inc.

    properties
        root 
    end

    methods
        function fix = RegisterPackage
            
            fixtureSuffix = fullfile("+prodserver","+mcp","+test",...
                "+mixin");
            fix.root = fileparts(mfilename("fullpath"));
            fix.root = erase(root,fixtureSuffix);
        end

        function setup(fix)
            addpath(fix.root);
        end

        function teardown(fix)
            rmpath(fix.root);
        end

    end
end