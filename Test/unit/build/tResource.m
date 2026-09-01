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

    end
end