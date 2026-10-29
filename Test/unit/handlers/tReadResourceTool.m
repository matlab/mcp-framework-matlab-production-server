classdef tReadResourceTool < prodserver.mcp.test.base.MCPHandlerBase
% The built-in read_mcp_resource tool, and its agreement with resources/read.
%
% A resource can be read two ways: the resources/read protocol method, and the
% read_mcp_resource tool that ships on every server so resources work with
% clients that do not implement resource reads natively. Both end up in
% +handler/+resource/contents.m, so they must give the same answer about whether
% a resource exists. That agreement is what this file pins.
%
% Two defects, both on the miss path, which was the one path nothing covered:
%
%   1. The tool synthesized a resource when the URI matched nothing -- mimeType
%      text/plain, text "" -- purely to satisfy its (1,1) struct output
%      validation. A mistyped URI came back as a SUCCESSFUL read of an empty
%      resource, so an LLM had no way to tell "absent" from "present and blank",
%      and the tool fabricated exactly the content its own description tells the
%      model never to fabricate. Meanwhile resources/read reported the same URI
%      as a JSON-RPC error, so the two paths contradicted each other.
%
%   2. That synthesized struct named the field url, while the hit path names it
%      uri. One tool returned two different shapes, discriminated by nothing the
%      caller could see. uri is the correct name: MCP's ResourceContents
%      requires it, and the tool's input argument is now uri to match.
%
% Every test runs under each protocol revision (MCPHandlerBase's protocolParam).
% Only the resources/read error code differs between them.

% Copyright 2026 The MathWorks, Inc.

    properties (ClassSetupParameter)
        % The resource read path is wire-encoded, and Invertible returns string
        % where JSON returns char, so run both arms.
        encoding = { prodserver.mcp.WireEncoding.JSON, ...
            prodserver.mcp.WireEncoding.Invertible };
    end

    properties (Constant)
        % A URI shaped like a real one, differing from the built-in resource by
        % a plausible typo rather than being obvious nonsense.
        missingURI = "mcp://protocol/tools/wire-format/parameters/encoding_rule";
    end

    methods (TestClassSetup)

        function prepareTools(test, encoding)
            import matlab.unittest.fixtures.PathFixture

            test.applyFixture(PathFixture(fullfile( ...
                prodserver.mcp.internal.packageFolder(),"server","tools")));

            test.fcnNames = "read_mcp_resource";
            test.toolNames = "read_mcp_resource";
            defineTools(test,test.fcnNames,test.toolNames,encoding=encoding);
        end
    end

    methods

        function [response, reqT] = post(test, body)
        %post Send a JSON-RPC BODY under the current protocol revision.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];
            [req, body] = test.applyProtocol(req, body);
            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/prime/mcp";
            reqT.Headers = [reqT.Headers; {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");
            response = test.handle(reqT);
        end

        function [response, reqT] = callTool(test, uri)
        % The request is returned alongside the response because
        % structuredContent is wire-encoded, and decoding it needs to know
        % which tool was called in order to look up its encoding.
            body = sprintf(['{ "jsonrpc": "2.0", "id": 1, ' ...
                '"method": "tools/call", "params": { ' ...
                '"name": "read_mcp_resource", ' ...
                '"arguments": { "uri": "%s" } } }'], uri);
            [response, reqT] = test.post(body);
        end

        function response = readResource(test, uri)
            body = sprintf(['{ "jsonrpc": "2.0", "id": 1, ' ...
                '"method": "resources/read", "params": { "uri": "%s" } }'], uri);
            response = test.post(body);
        end

        function contents = toolContents(test, response, reqT)
        %toolContents The resource struct a tools/call read produced, wire-decoded.
            decoded = test.decodeResponse(reqT, response);
            test.assertTrue(prodserver.mcp.internal.hasField( ...
                decoded,"result.structuredContent.contents"), ...
                "Expected the tool to return resource contents");
            contents = decoded.result.structuredContent.contents;
        end

        function code = notFoundCode(test)
        %notFoundCode The resources/read error code for an unknown URI.
        %   2025-06-18 has a dedicated code; 2026-07-28 treats a URI that
        %   names nothing as an invalid parameter. Literals, not the
        %   constants, so the test does not agree with a wrong constant.
            if test.protocol == prodserver.mcp.protocol.v20250618.Constants.Version
                code = -32002;
            else
                code = -32602;
            end
        end
    end

    methods (Test)

        function tInputIsNamedUri(test)
        % The tool's own schema. resources/read takes params.uri, resource
        % listings report uri, and MCP names the field uri throughout; a tool
        % input called url asked a model to track two names for one concept.
            svc = prodserver.mcp.handler.toolServices;
            d = svc.(prodserver.mcp.MCPConstants.DefinitionVariable);
            t = d.tools{1};
            test.assertEqual(string(t.name),"read_mcp_resource");

            props = string(fieldnames(t.inputSchema.properties));
            test.verifyTrue(ismember("uri",props), ...
                "The tool input must be named uri");
            test.verifyFalse(ismember("url",props), ...
                "The tool input must not be named url");
            test.verifyTrue( ...
                any(contains(string(t.inputSchema.required),"uri")), ...
                "uri must be a required input");
        end

        function tKnownUriReadsAsUri(test)
        % The hit path, called directly. The field name is the assertion: it is
        % what the miss path used to disagree with.
            c = read_mcp_resource( ...
                prodserver.mcp.MCPConstants.WireEncodingResourceURI);

            test.verifyTrue(isfield(c,"uri"), ...
                "MCP ResourceContents requires a uri field");
            test.verifyFalse(isfield(c,"url"), ...
                "A resource read must not report url");
            test.verifyEqual(string(c.uri), ...
                prodserver.mcp.MCPConstants.WireEncodingResourceURI);
            test.verifyNotEmpty(c.text, ...
                "The built-in wire-encoding resource is not empty");
        end

        function tKnownUriReadsThroughToolsCall(test)
            [response, reqT] = test.callTool( ...
                prodserver.mcp.MCPConstants.WireEncodingResourceURI);

            test.verifyEqual(response.HttpCode, 200);
            jrpc = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(isfield(jrpc,"result"));
            test.verifyFalse(isfield(jrpc.result,"isError") && ...
                jrpc.result.isError, ...
                sprintf("A resource that exists must read cleanly: %s", ...
                    jsonencode(jrpc.result)));

            c = test.toolContents(response, reqT);
            test.verifyTrue(isfield(c,"uri"));
            test.verifyFalse(isfield(c,"url"));
        end

        function tMissingUriErrors(test)
        % Called directly: a failed read raises, rather than returning a
        % plausible-looking empty resource.
            test.verifyError( ...
                @()read_mcp_resource(test.missingURI), ...
                "prodserver:mcp:ResourceNotFound");
        end

        function tMissingUriIsAToolExecutionError(test)
        % Through tools/call. The tool ran and could not do what was asked, so
        % this is the isError channel over HTTP 200 -- not a JSON-RPC error,
        % which would say the protocol or the request was wrong.
            response = test.callTool(test.missingURI);

            test.verifyEqual(response.HttpCode, 200);
            jrpc = prodserver.mcp.internal.decodeBody(response);
            test.verifyFalse(isfield(jrpc,"error"), ...
                "A failed resource read is not a JSON-RPC protocol error");
            test.assertTrue(isfield(jrpc,"result"));
            test.verifyTrue(isfield(jrpc.result,"isError") && ...
                jrpc.result.isError, ...
                "A URI that matches nothing must report isError");
        end

        function tMissingUriDoesNotFabricateContent(test)
        % The regression test. The old branch returned a struct a client could
        % not distinguish from a real read of an empty resource, so the model
        % was told the resource existed and was blank.
            response = test.callTool(test.missingURI);
            jrpc = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(isfield(jrpc,"result"));

            test.verifyFalse(isfield(jrpc.result,"structuredContent"), ...
                "A failed read must not return resource contents");

            % And the model is told which URI failed, so it can correct a typo
            % rather than concluding the resource is empty.
            text = jsonencode(jrpc.result.content);
            test.verifyTrue(contains(text,"not found"), ...
                "The error must say the resource was not found");
            test.verifyTrue(contains(text,"encoding_rule"), ...
                "The error must name the URI that failed");
        end

        function tBothReadPathsAgreeOnAbsence(test)
        % The invariant the two defects broke. resources/read and the tool must
        % not disagree about whether a resource exists: they share
        % +handler/+resource/contents.m, and a client may use either.
            viaMethod = prodserver.mcp.internal.decodeBody( ...
                test.readResource(test.missingURI));
            viaTool = prodserver.mcp.internal.decodeBody( ...
                test.callTool(test.missingURI));

            % resources/read: a protocol-level error, because the client named
            % a resource in the request itself.
            test.assertTrue(isfield(viaMethod,"error"), ...
                "resources/read of an unknown URI must be a JSON-RPC error");
            test.verifyEqual(viaMethod.error.code, test.notFoundCode());

            % tools/call: isError, because the tool is what was named and the
            % tool ran. Different channels, same verdict -- and neither of them
            % reports success.
            test.assertTrue(isfield(viaTool,"result"));
            test.verifyTrue(isfield(viaTool.result,"isError") && ...
                viaTool.result.isError);
        end

        function tBothReadPathsAgreeOnPresence(test)
            uri = prodserver.mcp.MCPConstants.WireEncodingResourceURI;
            m = prodserver.mcp.internal.decodeBody(test.readResource(uri));
            [viaTool, reqT] = test.callTool(uri);
            t = prodserver.mcp.internal.decodeBody(viaTool);

            test.assertTrue(isfield(m,"result"));
            test.verifyFalse(isfield(m,"error"));
            test.assertTrue(isfield(t,"result"));
            test.verifyFalse(isfield(t.result,"isError") && t.result.isError);

            % Same resource, same uri, whichever way it was asked for.
            toolSide = test.toolContents(viaTool, reqT);
            viaMethodURI = string(m.result.contents(1).uri);
            viaToolURI = string(toolSide.uri);
            test.verifyEqual(viaMethodURI, viaToolURI);
            test.verifyEqual(viaMethodURI, uri);
        end

    end
end
