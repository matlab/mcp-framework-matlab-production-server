classdef tMustBeTestSpecification < matlab.unittest.TestCase
%tMustBeTestSpecification Unit tests for mustBeTestSpecification validator.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function addFramework(test)
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder, "../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end
    end

    methods(Test)

        function emptyIsValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeTestSpecification([]));
        end

        function functionHandleValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeTestSpecification(@() disp("x")));
        end

        function cellOfHandlesValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeTestSpecification({@() 1, @() 2}));
        end

        function stringFileValid(test)
            thisFile = string(mfilename("fullpath")) + ".m";
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeTestSpecification(thisFile));
        end

        function stringFolderValid(test)
            thisFolder = fileparts(mfilename("fullpath"));
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeTestSpecification(string(thisFolder)));
        end

        function stringFunctionNameValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeTestSpecification("disp"));
        end

        function numericErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeTestSpecification(42), ...
                "prodserver:mcp:InvalidTestSpecification");
        end

        function structErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeTestSpecification(struct()), ...
                "prodserver:mcp:InvalidTestSpecification");
        end

        function stringNotFoundErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeTestSpecification("nonExistent_xyz123"), ...
                "prodserver:mcp:TestSpecificationNotFound");
        end

        function cellWithBadElementErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeTestSpecification({@() 1, 42}), ...
                "prodserver:mcp:InvalidTestSpecification");
        end

    end
end
