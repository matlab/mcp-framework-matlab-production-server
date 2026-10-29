classdef tFileResource < prodserver.mcp.test.base.MCPHandlerBase
% File-based resources, from build-time loading to resources/read.
%
% Three defects, all on the file path:
%
%   1. The loader treated only text/* as text, while resources/read uses
%      isMIMETypeText. An application/json file was read as bytes and then
%      sent as "text", which jsonencode turned into a number array.
%   2. blob was sent as a JSON number array. MCP requires Base64.
%   3. The binary branch opened the file and never closed it.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        jsonURI = "mcp://test/file/json"
        binURI = "mcp://test/file/bin"
        jsonText = '{"answer":42,"name":"x_meta"}'
        binBytes = uint8([0 1 2 127 128 254 255])
    end

    properties
        jsonFile
        binFile
    end

    methods (TestClassSetup)

        function prepareResources(test)
            import prodserver.mcp.MCPConstants

            test.jsonFile = fullfile(test.tempFolder, "data.json");
            fid = fopen(test.jsonFile, "w");
            fwrite(fid, unicode2native(test.jsonText, "UTF-8"));
            fclose(fid);

            test.binFile = fullfile(test.tempFolder, "data.bin");
            fid = fopen(test.binFile, "w");
            fwrite(fid, test.binBytes);
            fclose(fid);

            % Any tool will do; only the resource list matters here.
            test.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                "server", "tools")));
            defineTools(test, "read_mcp_resource", "read_mcp_resource", ...
                encoding=prodserver.mcp.WireEncoding.JSON);

            def = load(test.definitionFile);
            def.(MCPConstants.ResourceVariable) = ...
                prodserver.mcp.internal.resourceDefinition({ ...
                    struct("uri", test.jsonURI, "mimeType", "application/json", ...
                        "contents", string(test.jsonFile)), ...
                    struct("uri", test.binURI, ...
                        "mimeType", "application/octet-stream", ...
                        "contents", string(test.binFile))});
            save(test.definitionFile, "-struct", "def");
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods

        function c = readContents(test, uri)
        %readContents The single contents entry resources/read returns.
            import prodserver.mcp.MCPConstants

            body = sprintf(['{ "jsonrpc": "2.0", "id": 1, ' ...
                '"method": "resources/read", "params": { "uri": "%s" } }'], uri);
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];
            [req, body] = test.applyProtocol(req, body);
            req.Method = "POST";
            req.Path = "/prime/mcp";
            req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body, "UTF-8");

            decoded = prodserver.mcp.internal.decodeBody(test.handle(req));
            test.assertTrue(prodserver.mcp.internal.hasField(decoded, ...
                "result.contents"), "Expected resource contents");
            c = decoded.result.contents;
            if iscell(c)
                c = c{1};
            end
        end
    end

    methods (Test)

        function jsonFileLoadsAsText(test)
            r = prodserver.mcp.internal.resourceDefinition({struct( ...
                "uri", test.jsonURI, "mimeType", "application/json", ...
                "contents", string(test.jsonFile))});
            test.verifyClass(r{1}.contents, "char");
            test.verifyEqual(r{1}.contents, test.jsonText);
        end

        function binaryFileLoadsAsBytes(test)
            before = numel(openedFiles);
            r = prodserver.mcp.internal.resourceDefinition({struct( ...
                "uri", test.binURI, "mimeType", "application/octet-stream", ...
                "contents", string(test.binFile))});
            test.verifyEqual(r{1}.contents, test.binBytes);
            test.verifyEqual(numel(openedFiles), before, ...
                "Loading a binary resource must close the file");
        end

        function jsonFileReadsAsText(test)
            c = readContents(test, test.jsonURI);
            test.verifyFalse(isfield(c, "blob"));
            test.assertTrue(isfield(c, "text"));
            test.verifyEqual(string(c.text), string(test.jsonText));
        end

        function binaryFileReadsAsBase64Blob(test)
            c = readContents(test, test.binURI);
            test.verifyFalse(isfield(c, "text"));
            test.assertTrue(isfield(c, "blob"));
            test.verifyTrue(ischar(c.blob) || isstring(c.blob), ...
                "blob must be a Base64 string, not a number array");
            test.verifyEqual(string(c.blob), ...
                string(matlab.net.base64encode(test.binBytes)));
            test.verifyEqual( ...
                prodserver.mcp.internal.base64decode(c.blob), test.binBytes);
        end

    end
end
