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
            % Extract path from endpoint
            u = prodserver.mcp.io.parseURI(endpoint); 
            reqT.Path = u.path;
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
        end

        function reqT = rawRequest(test, method, body, opts)
        %rawRequest Build a handler request with a verbatim body and full
        %   control over the session and protocol-version headers.
        %
        %   createRequest above always sets a session id and always builds a
        %   well-formed tools/call body. Conformance tests need the opposite:
        %   headers deliberately absent or blank, and bodies that are
        %   deliberately malformed.
        %
        %   session: "auto" mints a fresh uuid, "omit" sends no header at all,
        %   and any other value -- including "" -- is sent verbatim, which is
        %   how the blank-session case is expressed.
            arguments
                test
                method (1,1) string
                body (1,1) string = ""
                opts.session (1,1) string = "auto"
                opts.protocolVersion (1,1) string = "omit"
                opts.contentType (1,1) string = "application/json"
                opts.accept (1,1) string = "omit"
                opts.path (1,1) string = "/prime/mcp"
            end

            import prodserver.mcp.MCPConstants

            reqT = test.request;
            reqT.Method = method;
            reqT.Path = char(opts.path);

            if strlength(opts.contentType) > 0
                reqT.Headers = [reqT.Headers; ...
                    {MCPConstants.ContentType char(opts.contentType)}];
            end

            if opts.session ~= "omit"
                if opts.session == "auto"
                    value = char(matlab.lang.internal.uuid);
                else
                    value = char(opts.session);
                end
                reqT.Headers = [reqT.Headers; ...
                    {MCPConstants.SessionId value}];
            end

            if opts.protocolVersion ~= "omit"
                reqT.Headers = [reqT.Headers; ...
                    {MCPConstants.ProtocolVersion char(opts.protocolVersion)}];
            end

            if opts.accept ~= "omit"
                reqT.Headers = [reqT.Headers; ...
                    {'Accept' char(opts.accept)}];
            end

            if strlength(body) > 0
                reqT.Body = unicode2native(body,"UTF-8");
            else
                reqT.Body = uint8.empty(1,0);
            end
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength numel(reqT.Body)}];
        end

        function jrpc = responseBody(test, response)
        %responseBody Decode a handler response body as JSON-RPC.
            test.assertNotEmpty(response.Body, ...
                "Expected a JSON-RPC body in the response");
            jrpc = jsondecode(native2unicode(response.Body,"UTF-8"));
        end

        function verifyErrorCode(test, response, code, httpCode)
        %verifyErrorCode Assert a response is the JSON-RPC error it should be.
        %   The whole class of defect here is the HTTP status and the JSON-RPC
        %   error code disagreeing, so both are checked together, along with
        %   the rule that an error response carries no result.
            arguments
                test
                response
                code (1,1) double
                httpCode (1,1) double = 200
            end

            test.verifyConformantResponse(response);
            test.verifyEqual(response.HttpCode, httpCode);
            jrpc = test.responseBody(response);
            test.assertTrue(isfield(jrpc,"error"), ...
                "Response carries no error member");
            test.verifyEqual(jrpc.error.code, code);
            test.verifyFalse(isfield(jrpc,"result"), ...
                "An error response must not also carry a result");
            test.verifyTrue(isfield(jrpc,"id"), ...
                "A JSON-RPC error must report an id, null when unknown");
        end

        function verifyConformantResponse(test, response)
        %verifyConformantResponse Assert the transport invariants that hold
        %   for every MCP response, whatever the request was. Most of the
        %   conformance defects this guards against are invariant violations
        %   rather than mistakes in an individual case, so call this from
        %   every handler test in addition to the case-specific assertions.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.Constants

            hdrs = response.Headers;
            ct = prodserver.mcp.internal.getHeaderValue( ...
                MCPConstants.ContentType, hdrs);
            hasBody = ~isempty(response.Body);

            % Content-Type describes a body. A status that forbids one must
            % not advertise a type for the body it is not sending.
            if hasBody
                test.verifyEqual(string(ct), Constants.MIMETypeJSON, ...
                    "A response with a body must declare application/json");
            else
                test.verifyEmpty(ct, sprintf( ...
                    "HTTP %d has no body and must not set Content-Type", ...
                    response.HttpCode));
            end

            % Framing is MPS's job, for an empty body as much as a full one.
            % Measured on R2026b: MPS emits Content-Length on every response it
            % sends from a custom web handler, including Content-Length: 0 for
            % an empty body. A handler that states it as well does not make the
            % wire any clearer -- it puts the header on it twice, which this
            % suite cannot see, because the duplicate appears downstream of the
            % struct asserted on here.
            len = prodserver.mcp.internal.getHeaderValue( ...
                MCPConstants.ContentLength, hdrs);
            test.verifyEmpty(len, sprintf( ...
                "HTTP %d must leave Content-Length to MPS, but set it to '%s'", ...
                response.HttpCode, string(len)));

            % Whatever the status, no header may be sent twice: a duplicate is
            % how a client ends up honouring the value the server did not mean.
            [uniqueNames, ~, where] = unique(lower(string(hdrs(:,1))));
            duplicated = uniqueNames(accumarray(where,1) > 1);
            test.verifyEmpty(duplicated, ...
                "Duplicate response header(s): " + strjoin(duplicated,", "));

            % 202 and 204 forbid a body outright.
            if ismember(response.HttpCode, [202 204])
                test.verifyFalse(hasBody, sprintf( ...
                    "HTTP %d must carry no body", response.HttpCode));
            end

            % The session id is echoed from one place only; two sources
            % writing it would duplicate the header.
            names = string(hdrs(:,1));
            test.verifyLessThanOrEqual( ...
                nnz(strcmpi(names, string(MCPConstants.SessionId))), 1, ...
                "Mcp-Session-Id must appear at most once");

            if hasBody
                jrpc = jsondecode(native2unicode(response.Body,"UTF-8"));
                test.verifyEqual(string(jrpc.jsonrpc), ...
                    MCPConstants.jrpcVersion, ...
                    "Every JSON-RPC body must declare version 2.0");
                test.verifyFalse( ...
                    isfield(jrpc,"result") && isfield(jrpc,"error"), ...
                    "A JSON-RPC body carries result or error, never both");
            end
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
            end

            import prodserver.mcp.MCPConstants

            % Definition generation support in 26a and later.
            if nargin > 4
                dJSON = arrayfun(@(f)jsondecode(fileread(f)),opts.dFiles, ...
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