classdef tOptionalBI < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.MCPServer & ...
        prodserver.mcp.test.mixin.ExternalData
% Test generation and execution of MCP server with tools that have optional
% arguments.

% Copyright 2026, The MathWorks, Inc.

    properties
        toolFolder  % Root tools folder
        tempFolder  % Build artifacts generated into this folder
        server
    end

    methods(TestClassSetup)
        function initTest(test)
            testFolder = fileparts(mfilename("fullpath"));
            test.toolFolder = fullfile(testFolder,"..","..", ...
                "tools", "toyTools");
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

            % Put the temporary folder on the path so that the handler can
            % load the definition file. (This mimics the server
            % environment.)
            test.applyFixture(PathFixture(test.tempFolder));

            % Two tools which solve the same problem with different 
            % optional input strategies.
            fcn = ["toyScalarOptions", "toyScalarNVOptions"];

            % Build the tools into a Swiss Army knife of a server. 
            test.server = "Scaler";
            prodserver.mcp.build(fcn,folder=test.tempFolder,stop="Definition");

            % The wrappers should be in the temp folder
            d = dir(fullfile(test.tempFolder,"*MCP.m"));
            mcp = fcn + "MCP.m";
            test.verifyEqual(nnz(ismember(mcp,{d.name})),numel(fcn));
        end

    end

    methods(Test)

        function scalarOptions(test)
            % Call the tool that uses optional positional inputs, using 
            % the no-HTTP MCPServer (calls the handler function directly 
            % with a mock request object).

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Load the definition file (which is where the handler will
            % get its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "toyScalarOptions";

            % year, mpg, range, make, model
            args = { 1999,1001,100000,"Polaris","Zeta" };

            % Start by calling with all arguments, then drop them,
            % one-by-one.
            for n = numel(args):-1:1

                % Expected values
                expected = feval(fcn,args{1:n});
                
                t = findDefinition(fcn,def);
                s = def.signatures;
    
                body = jsonToolCall(test,fcn,2,t,s,args{1:n});
    
                req = mcpRequest(test,test.server,body=body);
                resp = handleRequest(test,req);
    
                % Test for call success
                test.verifyFalse(isfield(resp,'error'),"Error field present");
                test.verifyTrue(isfield(resp,'result'),"Result field missing");

                % Actual result - "report" is the name of the output
                % variable.
                actual = string(resp.result.structuredContent.report);

                % Test for correctness
                test.verifyEqual(actual, expected, "Iteration " + string(n));

            end
        end
    

        function scalarNVP(test)
            % Call the tool that uses name-value pair inputs, using 
            % the no-HTTP MCPServer (calls the handler function directly 
            % with a mock request object).

            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture

            % Load the definition file (which is where the handler will
            % get its list).
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "toyScalarNVOptions";

            % year, mpg, range, make, model
            year = 1999;
            values = { 1001,100000,"Polaris","Zeta" };
            names = { 'mpg', 'range', 'make', 'model' };
            args = [ names; values ]; args = { year, args{:} };

            % Start by calling with all arguments, then drop them,
            % one-by-one.
            for n = numel(args):-2:1

                % Expected values
                expected = feval(fcn,args{1:n});

                t = findDefinition(fcn,def);
                s = def.signatures;

                body = jsonToolCall(test,fcn,2,t,s,args{1:n});

                req = mcpRequest(test,test.server,body=body);
                resp = handleRequest(test,req);

                % Test for call success
                test.verifyFalse(isfield(resp,'error'),"Error field present");
                test.verifyTrue(isfield(resp,'result'),"Result field missing");

                % Actual result - "report" is the name of the output
                % variable.
                actual = string(resp.result.structuredContent.report);

                % Test for correctness
                test.verifyEqual(actual, expected, "Iteration " + string(n));

            end
        end
    end
end

function t = findDefinition(tool,def)
    % Find the tool definition in the definition list
    tName = cellfun(@(t)t.name,def.tools);
    k = strcmp(tool,tName);
    t = def.tools{k};
end