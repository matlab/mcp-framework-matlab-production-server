classdef tUri2json < matlab.unittest.TestCase
% The built-in uri2json tool, which an MCP App's view uses to read data.
% It reads a registered resource if the URI names one, and otherwise reads
% the URI with MarshallURI.

% Copyright 2026 The MathWorks, Inc.

    properties
        folder
        csv
        registered    % A file the file: scheme can read, also a resource
    end

    methods (TestClassSetup)
        function addTools(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(PathFixture(fullfile( ...
                prodserver.mcp.internal.packageFolder(), "server", "tools")));
        end
    end

    methods (TestMethodSetup)
        function seedDefinitions(test)
        % A definition file with one registered resource, and a data file.
            import prodserver.mcp.MCPConstants
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tFolder = test.applyFixture(TemporaryFolderFixture);
            test.folder = tFolder.Folder;
            test.applyFixture(PathFixture(test.folder));

            test.csv = fullfile(test.folder, "signal.csv");
            writematrix([1; 2; 3], test.csv);
            test.registered = fullfile(test.folder, "registered.csv");
            writematrix([9; 9; 9], test.registered);

            def.(MCPConstants.ResourceVariable) = { ...
                struct("uri", "ui://app/app.html", ...
                    "mimeType", MCPConstants.AppResourceMimeType, ...
                    "contents", "<html></html>"), ...
                struct("uri", prodserver.mcp.io.uri.File.Path2FileURI(test.registered), ...
                    "mimeType", "text/plain", "contents", "registered")};
            save(fullfile(test.folder, MCPConstants.DefinitionFile), ...
                "-struct", "def");

            % The definitions are cached; clear them now and afterwards, so
            % these resources reach only this test.
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function tRegisteredResource(test)
        % A registered resource comes back as its resources/read contents.
            r = uri2json("ui://app/app.html");
            test.verifyEqual(string(r.uri), "ui://app/app.html");
            test.verifyEqual(string(r.mimeType), ...
                prodserver.mcp.MCPConstants.AppResourceMimeType);
            test.verifyEqual(string(r.text), "<html></html>");
        end

        function tResourceBeforeScheme(test)
        % A URI that names a registered resource is read from the resource,
        % even when the scheme could read it too.
            r = uri2json(prodserver.mcp.io.uri.File.Path2FileURI(test.registered));
            test.verifyEqual(string(r.text), "registered");
            test.verifyFalse(isfield(r, "data"), ...
                "The file's data, not the resource, was returned");
        end

        function tFileURI(test)
        % Any other URI is read with MarshallURI, and its data returned.
            r = uri2json(prodserver.mcp.io.uri.File.Path2FileURI(test.csv));
            test.verifyEqual(r.data, [1; 2; 3]);
        end

        function tMissingFile(test)
            test.verifyError(@() uri2json(prodserver.mcp.io.uri.File.Path2FileURI( ...
                fullfile(test.folder, "missing.csv"))), ...
                "prodserver:mcp:InaccessibleDataSource");
        end

        function tUnknownScheme(test)
            test.verifyError(@() uri2json("nosuch://x"), ...
                "prodserver:mcp:UnknownScheme");
        end

    end
end
