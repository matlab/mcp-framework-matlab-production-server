classdef tmultiTool < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.MCPServer & ...
        prodserver.mcp.test.mixin.ExternalData
% Test generation and execution of MCP server with multiple tools.

% Copyright 2025, The MathWorks, Inc.

    properties
        toolFolder  % Root tools folder
        tempFolder  % Build artifacts generated into this folder
        tool        % Names of the tools
        fcn         % Function called by the corresponding tool
        server
    end

    methods(TestClassSetup)
        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.toolFolder = fullfile(testFolder,"..","..","..", ...
                "Examples", "MultiTool");
        end

        function buildServer(test)
        %buildServer Create the MCP server.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            % Put the tools on the path, so build can find them.
            test.applyFixture(PathFixture(test.toolFolder));

            % Create a temporary folder for all the deployment artifacts
            tempDir = TemporaryFolderFixture(WithSuffix="t h e w a i n");
            test.applyFixture(tempDir);
            test.tempFolder = tempDir.Folder;

            % Seven functions and seven tools and one server MCP.
            test.tool = ["twinDragon", "chaos", "snowflake", "mandelbrot", ...
                "dragonDraw", "turtleGraphic", "renderPointCloud"];

            test.fcn = ["chaosdragon", "chaosfractal", "snowflake", ...
                "mandelbrot", "renderDragon", "drawvector", "drawpoints"];

            % Build the tools into a Swiss Army knife of a server. 
            test.server = "Fractalizer";
            ctf = prodserver.mcp.build(test.fcn,tool=test.tool,...
                archive=test.server, folder=test.tempFolder);

            % The archive should be in the temp folder
            test.verifyTrue(startsWith(ctf,test.tempFolder),ctf);
        end

    end

    methods(Test)
        function wrapAndDefine(test)
        % Validate the generated wrapper functions and tool definitions.

            import prodserver.mcp.MCPConstants

            % Each tool should have a wrapper function that ends with MCP.
            for n = 1:numel(test.tool)
                wrapper = fullfile(test.tempFolder,test.fcn(n) + ...
                    MCPConstants.WrapperFileSuffix + ".m");
                test.verifyEqual(exist(wrapper,"file"),2,wrapper);
            end

            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            test.verifyEqual(numel(def.tools),numel(test.tool),"Number of tools");
            for n = 1:numel(def.tools)
                % Tool name correct
                test.verifyEqual(def.tools{n}.name,test.tool(n),...
                    "Tool number: "+string(n));

                % Tool has a signature
                test.verifyTrue(isfield(def.(MCPConstants.SignatureVariable),...
                    def.tools{n}.name), def.tools{n}.name);

                % Signature maps tool name to function name.
                sig = def.(MCPConstants.SignatureVariable).(def.tools{n}.name);
                test.verifyEqual(string(sig.function), ...
                    test.fcn(n) + MCPConstants.WrapperFileSuffix, ...
                    def.tools{n}.name);
            end
        end

        function listTools(test)
        % List the tools, using the no-HTTP MCPServer (calls the handler
        % function directly with a mock request object).

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Put the temporary folder on the path so that the handler can
            % load the definition file. (This mimics the server
            % environment.)
            test.applyFixture(PathFixture(test.tempFolder));

            % List all tools
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/list",' ...
                '"params": { "cursor": "optional-cursor-value"}}'];
            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");

            % Load the definition file (which is where the handler should
            % have gotten its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            % Basic verification
            test.verifyEqual(numel(resp.result.tools),numel(def.tools), ...
                "Tool count");
            test.verifyTrue(isempty(setxor({resp.result.tools.name},...
                test.tool)),"Tool name mismatch");

            % Every tool in the list should have an equivalent in the
            % definition data.
            atd = resp.result.tools;  % Actual

            etd = def.tools;          % Expected
            etd = jsondecode(jsonencode(etd));  % Strings -> char, mostly

            eNames = string({etd.name});
  
            % Probably could compare atd and etd directly (order is
            % probably the name). But that may not always be the case. And
            % since order is not important, don't test for it.
            for n=1:numel(atd)
                % Find the expected tool with the same name as the actual
                % tool.
                k = strcmp(atd(n).name,eNames);
                test.verifyEqual(nnz(k),1,"Wrong number of tools names match");

                % The actual and expected data must match.
                test.verifyEqual(atd(n),etd(k),"Tool definition mismatch");
            end
        end


        function callSnowflake(test)
        % Call the tools, using the no-HTTP MCPServer (calls the handler
        % function directly with a mock request object).

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Put the temporary folder on the path so that the handler can
            % load the definition file. (This mimics the server
            % environment.)
            test.applyFixture(PathFixture(test.tempFolder));

            % Load the definition file (which is where the handler will
            % get its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            % Expected values
            width = 600; height=600; n = 5;
            [vectors, bbox] = snowflake(n, width, height);

            vectorsURL = locate(test,"vectors",test.tempFolder);
            bboxURL = locate(test,"bbox",test.tempFolder);

            t = findDefinition("snowflake",def);

            body = jsonToolCall(test,"snowflake",2,t,n,width,height, ...
                vectorsURL,bboxURL);

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");

            v = fetch(test,vectorsURL);
            test.verifyEqual(v,vectors,"snowflake vectors");

            b = fetch(test,bboxURL);
            test.verifyEqual(b,bbox,"snowflake bbox");

            t = findDefinition("turtleGraphic",def);

            jpg = fullfile(test.tempFolder,"snowflake.jpg");
            body = jsonToolCall(test,"turtleGraphic",3,t,bboxURL,vectorsURL,...
                width,height,jpg);

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");
            test.verifyEqual(exist(jpg,"file"),2,jpg);

            % Mostly testing that a JPG was created. Content is probably
            % right. But at this point we know that two tools worked
            % together.
            snow = imfinfo(jpg);
            test.verifyEqual(snow.Format,'jpg');
            test.verifyEqual(snow.BitDepth,24);
        end

        function callDragon(test)

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Put the temporary folder on the path so that the handler can
            % load the definition file. (This mimics the server
            % environment.)
            test.applyFixture(PathFixture(test.tempFolder));

            % Load the definition file (which is where the handler will
            % get its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            %
            % twinDragon(N,dragonURL)
            %

            % Fixed value for random seed to set sequence of random points.
            rng(8675309,"twister");

            n = 50000;
            dragon = chaosdragon(n);

            dragonURL = locate(test,"twinDragon",test.tempFolder);

            t = findDefinition("twinDragon",def);

            body = jsonToolCall(test,"twinDragon",2,t,n,dragonURL);

            % Reset seed to guarantee same sequence of random points.
            rng(8675309,"twister");

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");

            % Increase tolerance of floating point equality to account for
            % loss of precision when writing to file. (Might not be a
            % problem for MAT-files.)
            d = fetch(test,dragonURL);
            test.verifyEqual(d,dragon,"dragon points",AbsTol=1e-12);
 
            %
            % dragonDraw(dragonURL,color1,color2,fileURL,szURL)
            %

            jpg = fullfile(test.tempFolder,"dragonImage.jpg");
            szURL = locate(test,"dragonSize",test.tempFolder);
            color1 = "#EDB120";
            color2 = "#8516D1";

            t = findDefinition("dragonDraw",def);

            body = jsonToolCall(test,"dragonDraw",2,t,dragonURL,color1,...
                color2,jpg,szURL);

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");
            test.verifyEqual(exist(jpg,"file"),2,jpg);

            % Mostly testing that a JPG was created. Content is probably
            % right. But at this point we know that two tools worked
            % together.
            twins = imfinfo(jpg);
            test.verifyEqual(twins.Format,'jpg');
            test.verifyEqual(twins.BitDepth,24);

        end

        function callFractal(test)

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Put the temporary folder on the path so that the handler can
            % load the definition file. (This mimics the server
            % environment.)
            test.applyFixture(PathFixture(test.tempFolder));

            % Load the definition file (which is where the handler will
            % get its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            %
            % chaos(N,sides,xyURL,hueURL,opts)
            %

            % Fixed value for random seed to set sequence of random points.
            rng(4171961,"twister");

            n = 10000;
            sides = 5;
            [xyExpected,hueExpected] = chaosfractal(n,sides);

            xyURL = locate(test,"chaosXY",test.tempFolder);
            hueURL = locate(test,"chaosHue",test.tempFolder);

            t = findDefinition("chaos",def);

            body = jsonToolCall(test,"chaos",2,t,n,sides,xyURL,hueURL);

            % Reset seed to guarantee same sequence of random points.
            rng(4171961,"twister");

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");

            xyActual = fetch(test,xyURL);
            test.verifyEqual(xyActual,xyExpected,"chaos points");

            hueActual = fetch(test,hueURL);
            test.verifyEqual(hueActual,hueExpected,"chaos hue");

            % renderPointCloud(xyURL,jpg,hueURL=hueURL)
            jpg = fullfile(test.tempFolder,"chaosImage.jpg");

            t = findDefinition("renderPointCloud",def);

            body = jsonToolCall(test,"renderPointCloud",2,t,xyURL,jpg, ...
                hueURL=hueURL);

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");
            test.verifyEqual(exist(jpg,"file"),2,jpg);

            % Mostly testing that a JPG was created. Content is probably
            % right. But at this point we know that two tools worked
            % together.
            pentagram = imfinfo(jpg);
            test.verifyEqual(pentagram.Format,'jpg');
            test.verifyEqual(pentagram.BitDepth,24);
        end

        function callMandelbrot(test)
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Put the temporary folder on the path so that the handler can
            % load the definition file. (This mimics the server
            % environment.)
            test.applyFixture(PathFixture(test.tempFolder));

            % Load the definition file (which is where the handler will
            % get its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            %
            % mandelbrot(width,iterations,mURL)
            %

            n = 1000;
            width = 600;
            m = mandelbrot(n, width);

            mandelbrotSetURL = locate(test,"mandelbrotSet",test.tempFolder);

            t = findDefinition("mandelbrot",def);

            body = jsonToolCall(test,"mandelbrot",2,t,n,width,mandelbrotSetURL);

            req = mcpRequest(test,test.server,body=body);
            resp = handleRequest(test,req);

            % Test for call success
            test.verifyFalse(isfield(resp,'error'),"Error field present");
            test.verifyTrue(isfield(resp,'result'),"Result field missing");

            mandelbrotActual = fetch(test,mandelbrotSetURL);
            test.verifyEqual(mandelbrotActual,m,"mandelbrot points");
        end

    end
end

function t = findDefinition(tool,def)
    % Find the tool definition in the definition list
    tName = cellfun(@(t)t.name,def.tools);
    k = strcmp(tool,tName);
    t = def.tools{k};
end