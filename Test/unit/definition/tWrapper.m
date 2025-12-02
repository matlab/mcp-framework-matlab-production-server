classdef tWrapper < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.ExternalData

    properties
        toolFolder
    end

    methods (TestClassSetup)

        function registerPackage(test)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end

        function initPath(test)
            % Put the toyTools folder on the path.
            import matlab.unittest.fixtures.PathFixture
            test.toolFolder = fullfile(fileparts(mfilename("fullpath")),...
                "..", "..", "tools","toyTools");
            test.applyFixture(PathFixture(test.toolFolder));
        end
    end

    methods
        function validateWrapperText(test,tool,code)
            % Grab the known-good wrapper (which "code" should match
            % exactly).
            wrapFile = fullfile(test.toolFolder,tool+".wrap");
            wrap = readlines(wrapFile);

            % The generated code contains a unique UUID-named variable. In
            % order for the .wrap file to match exactly that variable must
            % be injected into the .wrap file.
            varPattern = "v" + alphanumericsPattern + asManyOfPattern("_"+alphanumericsPattern,4,4);
            marshalVar = unique(extract(code,varPattern));
            test.verifyEqual(numel(marshalVar),1,"Unique UUID variables.")
            wrap = replace(wrap,"!marshalVar",marshalVar);
            wrap = strjoin(wrap,newline);

            % Generated wrapper should be identical to "golden file".
            % Compare line by line to aid debugging / failure
            % identification.
            code = split(code,newline);
            wrap = split(wrap,newline);
            test.verifyEqual(numel(wrap),numel(code),"Wrong number of lines in " + tool);
            for n = 1:numel(code)
                test.verifyEqual(code(n),wrap(n),"Line " + string(n) + ...
                    ". Generated code: " + tool);
                if strcmp(code(n),wrap(n)) == 0
                    break;
                end
            end
        end

        function validateWrapperFile(test,tool,wrapFile)
        % Compare the contents of wrapFile to a known good wrapper for
        % tool.
            test.verifyEqual(exist(wrapFile,"file"),2,wrapFile);
            wrapCode = readlines(wrapFile);
            wrapCode = strjoin(wrapCode,newline);
            validateWrapperText(test,tool,wrapCode);
        end
    end

    methods(Test)

        function wrapMyriad(test)

            % Temporary folder to contain wrappers
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            wrapFolder = tFolder.Folder;

            % Generate wrappers for three tools
            fcn = ["toyToolOne", "toyToolTwo", "toyToolThree"];

            % Vanilla argument list -- tools only, no GenAI.
            wrap = prodserver.mcp.internal.wrapForMCP(fcn,["","",""], ...
                wrapFolder);

            test.verifyEqual(numel(wrap),numel(fcn),"Wrapper count");

            % If the wrapper text matches the golden files, that's a pass,
            % because the other tests in this file call the wrapper
            % functions AND check for a match with the golden files. Gotta
            % love equal's transitive property.
            for n = 1:numel(wrap)
                validateWrapperFile(test,fcn(n),wrap(n));
            end

        end

        function wrapLongComments(test)
            % Temporary folder to contain wrappers -- put it on the path so
            % feval can find the wrapper.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.MCPConstants

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            wrapFolder = tFolder.Folder;
            test.applyFixture(PathFixture(wrapFolder));

            % Generate wrappers for tool with duplicate names in
            % argument list.
            fcn = "toyToolThree";   
            wrapper = fcn + MCPConstants.WrapperFileSuffix;

            % Vanilla argument list -- tools only, no GenAI.
            wrapFile = prodserver.mcp.internal.wrapForMCP(fcn,"",...
                wrapFolder);
            rehash

            validateWrapperFile(test,fcn,wrapFile);

            % Collect the expected values
            three = "saam";
            two.two = "twice";
            one = { 48 };
            [one_out,two_out,three_out] = toyToolThree(three,two,one);

            threeURL = stow(test,wrapFolder,"three",three);
            twoURL = stow(test,wrapFolder,"two",two);
            oneURL = stow(test,wrapFolder,"one",one);

            oneOutURL = locate(test,"oneOut",wrapFolder);
            threeOutURL = locate(test,"threeOut",wrapFolder);

            two_w = feval(wrapper,threeURL,twoURL,oneURL,oneOutURL, ...
                threeOutURL);
            test.verifyEqual(two_w,two_out,"two_w");

            one_w = fetch(test,oneOutURL);
            test.verifyEqual(one_w,one_out,"one_w");

            three_w = fetch(test,threeOutURL);
            test.verifyEqual(three_w,three_out,"three_w");
        end


        function wrapDupNames(test)

            % Temporary folder to contain wrappers -- put it on the path so
            % feval can find the wrapper.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.internal.Constants

            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            wrapFolder = tFolder.Folder;
            test.applyFixture(PathFixture(wrapFolder));

            % Generate wrappers for tool with duplicate names in
            % argument list.
            fcn = "toyToolDupNames";
            wrapper = fcn + "MCP";

            % Vanilla argument list -- tools only, no GenAI.
            wrapFile = prodserver.mcp.internal.wrapForMCP(fcn,"",wrapFolder);
            rehash

            test.verifyEqual(exist(wrapFile,"file"),2,fcn);

            % 39th Heronian triangle, by my algorithm's count.
            b.x=16; b.y=17; b.z=17;

            % Call the original (unwrapped) function to get the expected
            % outputs.
            a = {"this","that"};
            x = ["names","of","things"];
            [out_a,out_b,c] = feval(fcn, a, x, b, 10);

            % Create the file URL inputs in the temporary folder.
            aURL = stow(test,wrapFolder,"a",a);
            xURL = stow(test,wrapFolder,"x",x);
            bURL = stow(test,wrapFolder,"b",b);
            out_bURL = locate(test,"out_b",wrapFolder);

            % Call the generated wrapper; test to be sure generated code
            % will actually run.
            [aMCP,cMCP] = feval(wrapper,aURL,xURL,bURL,10,out_bURL);

            % Check results against expected -- those generated by running
            % the original, unwrapped, function.
            test.verifyEqual(aMCP,out_a,"out_a");
            test.verifyEqual(cMCP,c,"c");
            bData = fetch(test,out_bURL);
            test.verifyEqual(bData,out_b,out_bURL);

        end

        function wrapOne(test)
        % Golden file-type test. Inherently fragile, but easy to write.

            import prodserver.mcp.internal.Constants

            % Generate a wrapper for toyToolOne
            tool = "toyToolOne";
            code = prodserver.mcp.internal.mcpWrapper(tool,tool+"MCP");

            validateWrapperText(test,tool,code);
            
            % Run the wrapper to make sure the generated function is actual,
            % working MATLAB code.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            tempFolder = TemporaryFolderFixture();
            test.applyFixture(tempFolder);
            test.applyFixture(PathFixture(tempFolder.Folder));

            writelines(code,fullfile(tempFolder.Folder,tool+"MCP.m"));
            rehash  % Otherwise the feval fails. A bug? Slow file system?

            a = 11;
            b = 7;
            urlFolder = string(tempFolder.Folder);

            % Inputs
            bFile = fullfile(urlFolder,"B.mat");
            save(bFile,"b");
            bURL = "file:" + bFile;
            bURL = replace(bURL,filesep,"/");

            % Outputs
            xURL = locate(test,"X",urlFolder);
            yURL = locate(test,"Y",urlFolder);
            zURL = locate(test,"Z",urlFolder);

            feval(tool+"MCP",a,bURL,xURL,yURL,zURL);

            x = fetch(test,xURL);
            y = fetch(test,yURL);
            z = fetch(test,zURL) ;

            test.verifyEqual(x, uint64(b .^ a), "X");
            test.verifyEqual(y, x + 64, "Y");
            test.verifyEqual(z, uint64(b - a), "Z")

        end

        function wrapArgOrder(test)
        % Wrap a function whose arguments are not in alphabetical order.
            import prodserver.mcp.internal.Constants
    
            % Generate a wrapper for toyToolTwo
            tool = "toyToolTwo";
            wrapper = tool+"MCP";
            code = prodserver.mcp.internal.mcpWrapper(tool,wrapper);
    
            validateWrapperText(test,tool,code);
    
            % Run the wrapper to make sure the generated function is actual,
            % working MATLAB code.
    
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            tempFolder = TemporaryFolderFixture();
            test.applyFixture(tempFolder);
            test.applyFixture(PathFixture(tempFolder.Folder));
    
            writelines(code,fullfile(tempFolder.Folder,tool+"MCP.m"));
            rehash  % Otherwise the feval fails. A bug? Slow file system?

            o = geom(3); m = geom(7);
            [c,a] = feval(tool,o,m);

            urlFolder = string(tempFolder.Folder);

            % Inputs
            oURL = stow(test,urlFolder,"O",o);
            mURL = stow(test,urlFolder,"M",m);

            % Outputs
            cURL = locate(test,"C",urlFolder);
            aURL = locate(test,"A",urlFolder);

            % Invoke wrapper
            feval(wrapper,oURL,mURL,cURL,aURL);

            cw = fetch(test,cURL); 
            aw = fetch(test,aURL);

            test.verifyEqual(cw,c,"chiral");
            test.verifyEqual(aw,a,"asymmetry");

        end
    end
end
