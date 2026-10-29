classdef MCPHandlerBase < matlab.unittest.TestCase

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolsFolder
        request
        tempFolder
        definitionFile
        toolNames
        fcnNames
        server
        protocol
    end

    properties (MethodSetupParameter)
        % Every registered revision, taken from the registry rather than
        % written out. This is the parameter that multiplies all 27 suites
        % built on this base, so a hardcoded list here is the single place
        % where adding an adapter would silently leave the whole test estate
        % running against the old revisions only -- green, and not testing
        % the new one at all.
        %
        % num2cell, because a MethodSetupParameter wants a cell of values and
        % supportedVersions returns a string array. The parameter names in
        % test output stay the version strings themselves.
        protocolParam = num2cell( ...
            prodserver.mcp.protocol.ProtocolRegistry.instance( ...
                ).supportedVersions())
    end

    methods (TestMethodSetup)
        function setupProtocol(test, protocolParam)
            test.protocol = protocolParam;
        end
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

            test.server = "http://localhost:9910/AnExcellentServer/mcp";

            test.request = struct(...
                'ApiVersion',[1 0 0], ...
                'Headers', {...
                {'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)';}}); 

            % Clear the appdata key
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods

        function reqT = createRequest(test,fcn,endpoint,varargin)
            import prodserver.mcp.MCPConstants

            % Get base request structure
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                char(prodserver.mcp.internal.Constants.MIMETypeJSON)}];

            % Add arguments to request body. Expect varargin to be
            % name/value pairs.
            body.jsonrpc = MCPConstants.jrpcVersion;
            body.id = 1;
            body.method = "tools/call";
            body.params.name = fcn;
            body.params.arguments = struct(varargin{:});

            [rows, body] = prodserver.mcp.test.protocolEnvelope( ...
                test.protocol, body);
            req.Headers = [req.Headers; rows];

            body = jsonencode(body);

            reqT = req;
            reqT.Method = "POST";  % Because there's a body
            % Extract path from endpoint
            u = prodserver.mcp.io.parseURI(endpoint);
            reqT.Path = u.path;
            % Content-Length counts bytes, not characters.
            reqT.Body = unicode2native(body,"UTF-8");
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(reqT.Body)}];
        end

        function [req, body] = applyProtocol(test, req, body)
        %applyProtocol Add protocol-specific envelope to a request.
        %   BODY is a JSON string. For 2025-06-18 it is returned unchanged;
        %   for 2026-07-28 it gains _meta. See test.protocolEnvelope.
        %   The 2025-06-18 body is not decoded at all, so a test may send one
        %   that is deliberately not a single JSON-RPC object.
            if test.protocol == prodserver.mcp.protocol.v20250618.Constants.Version
                rows = prodserver.mcp.test.protocolEnvelope(test.protocol, struct());
            else
                [rows, s] = prodserver.mcp.test.protocolEnvelope( ...
                    test.protocol, jsondecode(body));
                body = jsonencode(s);
            end
            req.Headers = [req.Headers; rows];
        end

        function response = handle(test, request)
        %handle Run mcpHandler and check the response's transport invariants.
            response = prodserver.mcp.internal.mcpHandler(request);
            prodserver.mcp.test.verifyConformantResponse(test, response);
        end

        function response = decodeResponse(test,request,response) %#ok<INUSL>
            response = prodserver.mcp.internal.decodeBody(response);
            response = prodserver.mcp.test.decodeStructuredContent(...
                request, response);
        end

        function defineTools(test,fcns,tools,opts)
            arguments
                test           % this
                fcns           % Names of functions in the server
                tools          % Tool name of each function
                opts.encoding  % Encoding used by the tool
                opts.dFiles    % JSON files containing complete definitions
                opts.definition % A complete definition struct, saved as is
            end

            import prodserver.mcp.MCPConstants

            % Definition generation support in 26a and later.
            if isfield(opts, "definition")
                % Built by the caller, for a shape the other two routes
                % cannot produce -- e.g. the one build(..., example=) saves,
                % whose observed signatures have no 'input' for a tool with
                % no inputs.
                definition = opts.definition;
            elseif isfield(opts, "dFiles")
                dJSON = arrayfun(@(f)jsondecode( ...
                    prodserver.mcp.internal.readUTF8(f)),opts.dFiles, ...
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
                    tools, fcns, encoding=opts.encoding);
            end

            test.definitionFile = fullfile(test.tempFolder,...
                MCPConstants.DefinitionFile);
            def.(MCPConstants.DefinitionVariable) = definition;
            def.(MCPConstants.ResourceVariable) = ...
                prodserver.mcp.internal.resourceDefinition({MCPConstants.WireEncodingResource});
            save(test.definitionFile,"-struct","def");

            % Clear the appdata key
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end
end