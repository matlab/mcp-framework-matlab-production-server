classdef MCPHandlerBase < matlab.unittest.TestCase
    properties
        toolsFolder
        request
        tempFolder
        definitionFile
        toolNames
        fcnNames
        server
    end

    methods (TestClassSetup)

        function initTest(test)
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            % Make a temporary folder for output and put it on the path
            tfolder = TemporaryFolderFixture;
            test.applyFixture(tfolder);
            test.tempFolder = tfolder.Folder;
            test.applyFixture(PathFixture(test.tempFolder));

            test.server = "http://localhost:9910/mcp";

            test.request = struct(...
                'ApiVersion',[1 0 0], ...
                'Headers', {...
                {'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)';}}); 
        end
    end

    methods

        function reqT = createRequest(test,fcn,endpoint,varargin)
            import prodserver.mcp.MCPConstants

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            % Make up a session ID
            id = matlab.lang.internal.uuid;
            req.Headers = [req.Headers; { MCPConstants.SessionId id} ];

            % Add arguments to request body. Expect varargin to be
            % name/value pairs.
            body.jsonrpc = "2.0";
            body.id = 1;
            body.method = "tools/call";
            body.params.name = fcn;
            body.params.arguments = struct(varargin{:});
            body = jsonencode(body);

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            reqT.Path = endpoint;
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
        end

        function defineTools(test,fcns,tools,dFiles)
            import prodserver.mcp.MCPConstants

            % Definition generation support in 26a and later.
            if nargin > 3
                dJSON = arrayfun(@(f)jsondecode(fileread(f)),dFiles, ...
                    UniformOutput=false);
                definition.tools = cell(1,numel(dJSON));
                for n = 1:numel(dJSON)
                    td = dJSON{n};
                    definition.tools{n} = td.tools;
                    for f = string(fieldnames(td.signatures))'
                        definition.signatures.(f) = td.signatures.(f);
                    end
                end
            else
                definition = prodserver.mcp.internal.defineForMCP(...
                    tools, fcns);
            end

            test.definitionFile = fullfile(test.tempFolder,...
                MCPConstants.DefinitionFile);
            def.(MCPConstants.DefinitionVariable) = definition;
            save(test.definitionFile,"-struct","def");

        end
    end
end