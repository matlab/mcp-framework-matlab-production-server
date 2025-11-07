classdef tArgBlock < matlab.unittest.TestCase
% Test argument block parsing. Some heuristics, so the parsing can fail in
% ways that MATLAB won't.

    properties
        exampleFolder
    end

    methods (TestClassSetup)
    
        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.exampleFolder = fullfile(testFolder,"..","..","..","Examples");
        end
    
    end
    
    methods (Test)
        
        function vanilla(test)
        % Main line workflow -- everything in order.

            import matlab.unittest.constraints.IsSameSetAs

            % Put the toyTools folder on the path.
            import matlab.unittest.fixtures.PathFixture
            thisFolder = fileparts(mfilename("fullpath"));
            test.applyFixture(PathFixture(fullfile(thisFolder,...
                "toyTools")));

            mf = metafunction("toyToolOne");
            [input, output] = prodserver.mcp.internal.parameterDescription(mf);

            test.verifyEqual(numEntries(input),nargin(mf.Name),"nargin");
            test.verifyEqual(numEntries(output),nargout(mf.Name),"nargout");

            % Inputs should match those returned by metafunction
            inName = arrayfun(@(id)string(id.Name),[mf.Signature.Inputs.Identifier]);
            test.verifyThat(keys(input),IsSameSetAs(inName),"inputs");

            % As should outputs
            outName = arrayfun(@(id)string(id.Name),[mf.Signature.Outputs.Identifier]);
            test.verifyThat(keys(output),IsSameSetAs(outName),"outputs");

            % metafunction doesn't provide description for arguments or
            % string form of validation, so hard-code the expected values 
            % here.
            
            test.verifyEqual(input("a").description, ...
                "A scalar, as if the declaration wasn't obvious");
            test.verifyEqual(input("b").description, ...
                "Who knows how big this could get?");

            test.verifyEqual(input("a").validation, "(1,1) double");
            test.verifyEqual(input("b").validation, "uint64");

            test.verifyEqual(output("x").description, "A powerful result");
            test.verifyEqual(output("y").description, "Power augmented by 2^8!");
            test.verifyEqual(output("z").description, "Not quite so much");
        end
    end
end