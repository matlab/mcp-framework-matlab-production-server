classdef tMustBeExampleSpecification < matlab.unittest.TestCase
%tMustBeExampleSpecification Unit tests for mustBeExampleSpecification validator.

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
                @() prodserver.mcp.validation.mustBeExampleSpecification([]));
        end

        function functionHandleValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeExampleSpecification(@() disp("x")));
        end

        function cellOfHandlesValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeExampleSpecification({@() 1, @() 2}));
        end

        function stringFileValid(test)
            thisFile = string(mfilename("fullpath")) + ".m";
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeExampleSpecification(thisFile));
        end

        function stringFolderValid(test)
            thisFolder = fileparts(mfilename("fullpath"));
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeExampleSpecification(string(thisFolder)));
        end

        function stringFunctionNameValid(test)
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeExampleSpecification("disp"));
        end

        function numericErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeExampleSpecification(42), ...
                "prodserver:mcp:InvalidExampleType");
        end

        function structErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeExampleSpecification(struct()), ...
                "prodserver:mcp:InvalidExampleType");
        end

        function stringNotFoundErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeExampleSpecification("nonExistent_xyz123"), ...
                "prodserver:mcp:ExampleSpecificationNotFound");
        end

        function cellWithBadElementErrors(test)
            test.verifyError(...
                @() prodserver.mcp.validation.mustBeExampleSpecification({@() 1, 42}), ...
                "prodserver:mcp:InvalidExampleSpecification");
        end

    end
end
