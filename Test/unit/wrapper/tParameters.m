classdef tParameters < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.ExternalData

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolsFolder
    end

    methods (TestClassSetup)

        function requireToyTools(test)
            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireParamTools());
            test.toolsFolder = rtt.toolFolder;
        end

    end

    methods
        function validateWrapperText(test,tool,code)
            % Grab the known-good wrapper (which "code" should match
            % exactly).
            wrapFile = fullfile(test.toolsFolder,tool+".wrap");
            wrap = readlines(wrapFile);

            % The generated code contains a unique UUID-named variable. In
            % order for the .wrap file to match exactly that variable must
            % be injected into the .wrap file.
            varPattern = "v" + alphanumericsPattern + asManyOfPattern("_"+alphanumericsPattern,4,4);
            marshalVar = unique(extract(code,varPattern));
            if ~isempty(marshalVar)
                test.verifyEqual(numel(marshalVar),1,"Unique UUID variables.")
                wrap = replace(wrap,"!marshalVar",marshalVar);
            end
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

        function allInRequired(test)
        % All inputs required

            import prodserver.mcp.internal.Constants
            import prodserver.mcp.MCPConstants

            % Generate a wrapper for threeFour
            tool = "threeFour";
            code = prodserver.mcp.internal.mcpWrapper(tool,tool+"MCP", ...
                encoding="Invertible");

            validateWrapperText(test,tool,code);

            % Run the wrapper to ensure the generated code works.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            tempFolder = TemporaryFolderFixture();
            test.applyFixture(tempFolder);
            test.applyFixture(PathFixture(tempFolder.Folder));

            toolFcn = tool + MCPConstants.WrapperFileSuffix;

            writelines(code,fullfile(tempFolder.Folder,toolFcn+".m"));
            rehash  % Otherwise the feval fails. A bug? Slow file system?

            a = 11;
            b = 7;
            c = 3;
            d = 19;

            [ax,ay,az] = feval(toolFcn,a,b,c,d);
            [ex,ey,ez] = feval(tool,a,b,c,d);
            test.verifyEqual(ax,ex,"X");
            test.verifyEqual(ay,ey,"Y");
            test.verifyEqual(az,ez,"Z");

        end

        function allInOptional(test)
        % All inputs optional (with default values)

            import prodserver.mcp.internal.Constants
            import prodserver.mcp.MCPConstants

            % Generate a wrapper for allInOptional
            tool = "allInOptional";
            code = prodserver.mcp.internal.mcpWrapper(tool,tool+"MCP", ...
                encoding="Invertible");

            validateWrapperText(test,tool,code);

            % Run the wrapper to ensure the generated code works.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            tempFolder = TemporaryFolderFixture();
            test.applyFixture(tempFolder);
            test.applyFixture(PathFixture(tempFolder.Folder));

            toolFcn = tool + MCPConstants.WrapperFileSuffix;

            writelines(code,fullfile(tempFolder.Folder,toolFcn+".m"));
            rehash  % Otherwise the feval fails. A bug? Slow file system?

            a = 11;
            b = 7;
            c = 3;
            d = 19;

            args = {a, b, c, d};
            for n = 1:numel(args)
                [ax,ay,az] = feval(toolFcn,args{1:n});
                [ex,ey,ez] = feval(tool,args{1:n});
                test.verifyEqual(ax,ex,"X @" + string(n));
                test.verifyEqual(ay,ey,"Y @" + string(n));
                test.verifyEqual(az,ez,"Z @" + string(n));
            end


        end

        function someInNVP(test)
        % Some inputs as name-value pairs.
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.MCPConstants

            % Generate a wrapper for someInNVP
            tool = "someInNVP";
            code = prodserver.mcp.internal.mcpWrapper(tool,tool+"MCP", ...
                encoding="Invertible");

            validateWrapperText(test,tool,code);

            % Run the wrapper to ensure the generated code works.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            tempFolder = TemporaryFolderFixture();
            test.applyFixture(tempFolder);
            test.applyFixture(PathFixture(tempFolder.Folder));

            toolFcn = tool + MCPConstants.WrapperFileSuffix;

            writelines(code,fullfile(tempFolder.Folder,toolFcn+".m"));
            rehash  % Otherwise the feval fails. A bug? Slow file system?

            a = 11;
            b = 7;
            c = 3;
            d = 19;

            [ax,ay,az] = feval(toolFcn,a,b,c=c,d=d);
            [ex,ey,ez] = feval(tool,a,b,c=c,d=d);
            test.verifyEqual(ax,ex,"X");
            test.verifyEqual(ay,ey,"Y");
            test.verifyEqual(az,ez,"Z");

        end

        function oneIndirectOutput(test)
        % One externalized output, all inputs required.

            import prodserver.mcp.internal.Constants

            % Generate a wrapper for oneIndirectOutput
            tool = "oneIndirectOutput";
            code = prodserver.mcp.internal.mcpWrapper(tool,tool+"MCP", ...
                encoding="Invertible");

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
            c = 3;
            d = 19;

            urlFolder = string(tempFolder.Folder);

            % Outputs
            yURL = sink(test,"Y",urlFolder);

            [ax,az] = feval(tool+"MCP",a,b,c,d,y=yURL);
            ay = fetch(test,yURL);

            [ex,ey,ez] = feval(tool,a,b,c,d);
            test.verifyEqual(ax,ex,"X");
            test.verifyEqual(ay,ey,"Y");
            test.verifyEqual(az,ez,"Z");
        end

        function allIndirect(test)
        % All inputs and outputs indirect, but none optional.

            import prodserver.mcp.internal.Constants

            % Generate a wrapper for allIndirect
            tool = "allIndirect";
            code = prodserver.mcp.internal.mcpWrapper(tool,tool+"MCP", ...
                encoding="Invertible");

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
            c = 3;
            d = 19;

            urlFolder = string(tempFolder.Folder);

            % Inputs
            aURL = stow(test,urlFolder,"a",a);
            bURL = stow(test,urlFolder,"b",b);
            cURL = stow(test,urlFolder,"c",c);
            dURL = stow(test,urlFolder,"d",d);
            
            % Outputs
            xURL = sink(test,"X",urlFolder);
            yURL = sink(test,"Y",urlFolder);
            zURL = sink(test,"Z",urlFolder);

            % Partial matching of unique optional input names. x matches
            % xURL, etc.
            feval(tool+"MCP",aURL,bURL,cURL,dURL,x=xURL,y=yURL,z=zURL);

            x = fetch(test,xURL);
            y = fetch(test,yURL);
            z = fetch(test,zURL) ;

            values = [a,b,c,d];
            test.verifyEqual(x, sum(values), "X");
            test.verifyEqual(y, prod(values), "Y");
            test.verifyEqual(z, mean(values), "Z")

        end
    end
end
