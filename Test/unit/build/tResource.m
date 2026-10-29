classdef tResource < matlab.unittest.TestCase 

% Copyright 2025-2026 The MathWorks, Inc.

    properties
        toolFolder
        tempFolder
    end

    methods (TestClassSetup)

        function registerPackage(test)
            % Ensure that the functions being tested are on the path.
            import matlab.unittest.fixtures.PathFixture
            testFolder = fileparts(mfilename("fullpath"));
            pkgFolder = fullfile(testFolder,"../../..");
            test.applyFixture(PathFixture(pkgFolder));
        end
    end

    methods (TestMethodSetup)

        function switchContext(~)
            % Clear the tool definition cache
            prodserver.mcp.handler.toolServices(action="clear");
        end

        function scratchSpace(test)
            % Temporary folder to contain wrappers
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
        end

    end

    methods 
        function validateWireEncoding(test, resource)
            import prodserver.mcp.MCPConstants

            test.verifyTrue(isfield(resource,"uri"),"uri missing");
            test.verifyTrue(isfield(resource,"contents"),"contents missing");
            test.verifyTrue(isfield(resource,"name"),"name missing");
            test.verifyTrue(isfield(resource,"description"),"description missing");
            test.verifyTrue(isfield(resource,"mimeType"),"mimeType missing");
            test.verifyTrue(isfield(resource,"title"),"title missing");

            % Known field values
            test.verifyEqual(resource.name, MCPConstants.WireEncodingResource.name);
            test.verifyEqual(resource.uri, MCPConstants.WireEncodingResource.uri);
            test.verifyEqual(resource.title, MCPConstants.WireEncodingResource.title);
            test.verifyEqual(resource.mimeType, MCPConstants.WireEncodingResource.mimeType);
            test.verifyEqual(resource.description, MCPConstants.WireEncodingResource.description);

            % Contents equal to the text in the file
            test.verifyEqual(resource.contents, ...
                fileread(MCPConstants.WireEncodingResource.contents));
        end
    end

    methods(Test)

        function defaultResource(test)
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.Constants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolFolder = rtt.toolFolder;
            test.applyFixture(PathFixture(test.toolFolder));

            % Build any random MCP tool -- all of them should have this
            % resource.
            prodserver.mcp.build("toyToolOne",stop="Definition", ...
                folder=test.tempFolder, encoding="Invertible");

            % Load the definition file
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            test.verifyTrue(isfield(def,MCPConstants.ResourceVariable),...
                "ResourceVariable missing");

            % There should be one resource, the default wire encoding.
            resource = def.(MCPConstants.ResourceVariable);
            test.verifyEqual(numel(resource),1,"Number of resources");

            validateWireEncoding(test,resource{1});

            % Read the resource with read_mcp_resource.
            test.applyFixture(PathFixture(test.tempFolder));
            test.applyFixture(PathFixture(fullfile(...
                prodserver.mcp.internal.packageFolder(),"server","tools")));
            contents = read_mcp_resource(MCPConstants.WireEncodingResourceURI);
            test.verifyEqual(contents.text,resource{1}.contents)
        end


        function clientResource(test)
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.Constants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolFolder = rtt.toolFolder;
            test.applyFixture(PathFixture(test.toolFolder));

            % Create the client resource
            clientResource = struct('uri', 'facts://example/resource', ...
                'contents', jsonencode('Sample contents for the resource'), ...
                'name', 'Client Resource', ...
                'description', 'This is a test client resource', ...
                'mimeType', Constants.MIMETypeJSON, ...
                'title', 'Client Resource Title');

            % Build any random MCP tool -- all of them should have this
            % resource.
            prodserver.mcp.build("toyToolOne",stop="Definition", ...
                folder=test.tempFolder, resource=clientResource, ...
                encoding="Invertible");

            % Load the definition file
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            test.verifyTrue(isfield(def,MCPConstants.ResourceVariable),...
                "ResourceVariable missing");

            % There should be two resources, the default wire encoding and
            % the client resource.
            resource = def.(MCPConstants.ResourceVariable);
            test.verifyEqual(numel(resource),2,"Number of resources");

            validateWireEncoding(test,resource{1});

            % Required fields
            test.verifyTrue(isfield(resource{2},"uri"),"uri missing");
            test.verifyTrue(isfield(resource{2},"contents"),"contents missing");
            test.verifyTrue(isfield(resource{2},"name"),"name missing");
            test.verifyTrue(isfield(resource{2},"description"),"description missing");
            test.verifyTrue(isfield(resource{2},"mimeType"),"mimeType missing");
            test.verifyTrue(isfield(resource{2},"title"),"title missing");

            % Known field values
            test.verifyEqual(resource{2}.name, clientResource.name);
            test.verifyEqual(resource{2}.uri, clientResource.uri);
            test.verifyEqual(resource{2}.title, clientResource.title);
            test.verifyEqual(resource{2}.mimeType, clientResource.mimeType);
            test.verifyEqual(resource{2}.description, clientResource.description);
            test.verifyEqual(resource{2}.contents, clientResource.contents);

        end

        function wireEncodingResource(test)
        % Ensure that the wire encoding resource is placed into the
        % definition file.

            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.toolFolder = rtt.toolFolder;
            test.applyFixture(PathFixture(test.toolFolder));

            % Build any random MCP tool -- all of them should have this
            % resource.
            prodserver.mcp.build("toyToolOne",stop="Definition", ...
                folder=test.tempFolder, encoding="Invertible");

            % Load the definition file
            def = load(fullfile(test.tempFolder,MCPConstants.DefinitionFile));
            test.verifyTrue(isfield(def,MCPConstants.ResourceVariable),...
                "ResourceVariable missing");

            % Required fields
            resource = def.(MCPConstants.ResourceVariable);
            validateWireEncoding(test,resource{1});

        end

        function contentsTypes(test)
            % Contents may be text, raw bytes or a function that returns
            % the resource. The first of these used to be the only one:
            % a value that wasn't text was rejected before the others
            % were tried.
            v = @prodserver.mcp.validation.mustBeResource;
            u = 'mcp://test/r';
            test.verifyWarningFree(@() v(struct('uri', u, 'contents', "text")));
            test.verifyWarningFree(@() v(struct('uri', u, 'contents', ...
                uint8([137 80 78 71]), 'mimeType', 'image/png')));
            test.verifyWarningFree(@() v(struct('uri', u, ...
                'contents', @generatedResource)));
            test.verifyError(@() v(struct('uri', u, 'contents', [1 2 3])), ...
                "prodserver:mcp:InvalidResourceFieldType");
        end

        function binaryFunctionAndEmptyMIMEType(test)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.Constants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(matlab.unittest.fixtures.PathFixture(rtt.toolFolder));

            % A struct array, so every element has every field.
            bytes = uint8([137 80 78 71 13 10 26 10]);
            r = struct('uri', 'mcp://test/binary', 'contents', bytes, ...
                'mimeType', 'image/png');
            r(2).uri = 'mcp://test/generated';
            r(2).contents = @generatedResource;
            r(2).mimeType = '';
            r(3).uri = 'mcp://test/literal';
            r(3).contents = 'Plain words';
            r(3).mimeType = '';
            prodserver.mcp.build("toyToolOne", stop="Definition", ...
                folder=test.tempFolder, resource=r);
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            resource = def.(MCPConstants.ResourceVariable);
            uris = cellfun(@(x) string(x.uri), resource);

            binary = resource{uris == "mcp://test/binary"};
            test.verifyEqual(binary.contents, bytes, "Raw bytes kept");
            test.verifyEqual(string(binary.mimeType), "image/png");

            generated = resource{uris == "mcp://test/generated"};
            test.verifyEqual(string(generated.contents), "Generated words");
            test.verifyEqual(string(generated.name), "generatedResource", ...
                "Named after the function");

            % An empty mimeType is no mimeType: plain text, not binary.
            literal = resource{uris == "mcp://test/literal"};
            test.verifyEqual(string(literal.mimeType), ...
                string(Constants.MIMETypePlainText));
        end

        function binaryWithoutMIMEType(test)
            % Raw bytes with no mimeType default to
            % application/octet-stream, and are read as a blob. Without a
            % mimeType, resources/read raised.
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            rtt = test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(rtt.toolFolder));

            bytes = uint8([0 1 2 254 255]);
            prodserver.mcp.build("toyToolOne", stop="Definition", ...
                folder=test.tempFolder, ...
                resource=struct('uri', 'mcp://test/bytes', 'contents', bytes));
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            resource = def.(MCPConstants.ResourceVariable);
            uris = cellfun(@(x) string(x.uri), resource);
            test.verifyEqual(string(resource{uris == "mcp://test/bytes"}.mimeType), ...
                "application/octet-stream");

            test.applyFixture(PathFixture(test.tempFolder));
            data = prodserver.mcp.handler.resource.contents("mcp://test/bytes");
            test.verifyEqual(string(data.mimeType), "application/octet-stream");
            test.verifyFalse(isfield(data, "text"), "Bytes are not text");
            test.verifyEqual(string(data.blob), ...
                string(prodserver.mcp.internal.base64encode(bytes)));
        end

    end
end

function r = generatedResource()
% A resource made by a function, as a resource's contents may be.
    r = struct('uri', 'mcp://test/generated', 'contents', 'Generated words');
end