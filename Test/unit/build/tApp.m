classdef tApp < matlab.unittest.TestCase
% Test that build with app= creates the correct resource, injects _meta.ui
% into user tool definitions, and skips builtin tools.

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
    end

    methods (TestClassSetup)
        function initPath(test)
            test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());
        end
    end

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tFolder = TemporaryFolderFixture;
            test.applyFixture(tFolder);
            test.tempFolder = tFolder.Folder;
        end
    end

    methods (Test)

        function tAppResourceCreated(test)
        % build with app= produces a ui:// resource with correct MIME type.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            resources = d.(MCPConstants.ResourceVariable);
            uris = cellfun(@(r) string(r.uri), resources);
            idx = startsWith(uris, "ui://");
            test.verifyTrue(any(idx), "No ui:// resource found");

            appRes = resources{find(idx, 1)};
            test.verifyEqual(string(appRes.mimeType), ...
                MCPConstants.AppResourceMimeType);
        end

        function tAppMetaInjected(test)
        % User tool definitions contain x_meta.ui.resourceUri.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;

            userTool = tools{1};
            test.verifyEqual(string(userTool.name), "toyToolOne");
            test.verifyTrue(isfield(userTool, MCPConstants.MetaField), ...
                "User tool missing " + MCPConstants.MetaField);
            % The URI of the resource the server serves, or a host shows no
            % view.
            resources = d.(MCPConstants.ResourceVariable);
            uris = cellfun(@(r) string(r.uri), resources);
            served = uris(startsWith(uris, "ui://"));
            test.assertNumElements(served, 1);
            test.verifyEqual(string(userTool.(MCPConstants.MetaField).ui.resourceUri), ...
                served);
        end

        function tAppSkipsBuiltinTool(test)
        % read_mcp_resource does NOT get x_meta.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;

            builtinIdx = cellfun(@(t) ...
                string(t.name) == MCPConstants.ReadResourceTool, tools);
            test.verifyTrue(any(builtinIdx), ...
                "read_mcp_resource not found in tools");

            builtinTool = tools{find(builtinIdx, 1)};
            test.verifyFalse(isfield(builtinTool, MCPConstants.MetaField), ...
                "read_mcp_resource should not have " + MCPConstants.MetaField);
        end

        function tAppWithExample(test)
        % app= with example= defines the user tool, the resource reader
        % and uri2json, and still injects _meta.ui.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile, ...
                example={@() toyToolOne(1, uint64(2))});

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;
            names = cellfun(@(t) string(t.name), tools);
            test.verifyEqual(names, ["toyToolOne", ...
                MCPConstants.ReadResourceTool, MCPConstants.Uri2JsonTool]);
            test.verifyTrue(isfield(tools{1}, MCPConstants.MetaField), ...
                "User tool missing " + MCPConstants.MetaField);
        end

        function tAppUri2jsonHasNoView(test)
        % uri2json is listed, but no view is linked to it.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;
            k = cellfun(@(t) string(t.name) == MCPConstants.Uri2JsonTool, tools);
            test.verifyEqual(nnz(k), 1, "uri2json should be listed once");
            u = tools{k};
            test.verifyFalse(isfield(u, MCPConstants.MetaField) && ...
                isfield(u.(MCPConstants.MetaField), "ui") && ...
                isfield(u.(MCPConstants.MetaField).ui, "resourceUri"), ...
                "uri2json should have no resourceUri");
        end

        function tAppUri2jsonAppOnly(test)
        % uri2json is marked for the view only, as the JSON array ["app"].

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;
            u = tools{cellfun(@(t) string(t.name) == MCPConstants.Uri2JsonTool, tools)};
            visibility = u.(MCPConstants.MetaField).ui.visibility;
            test.verifyEqual(jsonencode(visibility), '["app"]');

            % The user tool keeps the default visibility: model and app.
            test.verifyFalse(isfield(tools{1}.(MCPConstants.MetaField).ui, ...
                "visibility"));
        end

        function tAppSharedByTools(test)
        % Every tool built with the app gets the same view.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build(["toyScalarOne", "toyScalarTwo"], ...
                folder=test.tempFolder, stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;
            uris = cellfun(@(t) string(t.(MCPConstants.MetaField).ui.resourceUri), ...
                tools(1:2));
            test.verifyEqual(uris(1), uris(2));
            test.verifyTrue(startsWith(uris(1), "ui://"));
        end

        function tAppFolderRejected(test)
        % A folder isn't an app: build stops, rather than serving the
        % folder's path as the view.

            test.verifyError( ...
                @() prodserver.mcp.build("toyToolOne", ...
                    folder=test.tempFolder, stop="Definition", ...
                    app=test.tempFolder), ...
                "prodserver:mcp:NotAFile");
        end

        function tAppEmptyStringIsNoApp(test)
        % An empty app builds as though no app were given.

            import prodserver.mcp.MCPConstants

            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app="");

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            test.verifyFalse(isfield(d, MCPConstants.AppResourceVariable), ...
                "No app flag expected for an empty app");
            names = cellfun(@(t) string(t.name), ...
                d.(MCPConstants.DefinitionVariable).tools);
            test.verifyFalse(ismember(MCPConstants.Uri2JsonTool, names), ...
                "No uri2json expected for an empty app");
        end

        function tAppMissingRejected(test)
        % A missing string isn't a file name.

            test.verifyError( ...
                @() prodserver.mcp.build("toyToolOne", ...
                    folder=test.tempFolder, stop="Definition", ...
                    app=string(missing)), ...
                "prodserver:mcp:FileNotFound");
        end

        function tAppOneFileOnly(test)
        % app takes one file.

            appFile = writeAppFile(test);
            test.verifyError( ...
                @() prodserver.mcp.build("toyToolOne", ...
                    folder=test.tempFolder, stop="Definition", ...
                    app=[appFile, appFile]), ...
                "MATLAB:validators:mustBeScalarOrEmpty");
        end

        function tAppFileNotFound(test)
        % Error when app= points to a nonexistent file.

            test.verifyError( ...
                @() prodserver.mcp.build("toyToolOne", ...
                    folder=test.tempFolder, stop="Definition", ...
                    app="/no/such/file.html"), ...
                "prodserver:mcp:FileNotFound");
        end

        function tNoAppBackwardCompatible(test)
        % Build without app= has no x_meta and no ui:// resource.

            import prodserver.mcp.MCPConstants

            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition");

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            tools = d.(MCPConstants.DefinitionVariable).tools;

            for n = 1:numel(tools)
                test.verifyFalse(isfield(tools{n}, MCPConstants.MetaField), ...
                    tools{n}.name + " should not have " + MCPConstants.MetaField);
            end

            % A JSON-encoded build may have no resources at all: no wire
            % encoding rules, and no app.
            resources = d.(MCPConstants.ResourceVariable);
            uris = cellfun(@(r) string(r.uri), resources, UniformOutput=false);
            uris = [string.empty, uris{:}];
            test.verifyFalse(any(startsWith(uris, "ui://")), ...
                "No ui:// resource expected without app=");

            test.verifyFalse(isfield(d, MCPConstants.AppResourceVariable), ...
                "App flag should not be set without app=");
        end

        function tAppFlagStored(test)
        % build with app= stores the app flag in the definition file.

            import prodserver.mcp.MCPConstants

            appFile = writeAppFile(test);
            prodserver.mcp.build("toyToolOne", folder=test.tempFolder, ...
                stop="Definition", app=appFile);

            d = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            test.verifyTrue(isfield(d, MCPConstants.AppResourceVariable), ...
                "App flag missing from definition file");
        end

        function tReservedToolNames(test)
        % A user tool may not take the name of one of the framework's own
        % tools, with or without an app.
            appFile = writeAppFile(test);
            for name = ["uri2json", "read_mcp_resource"]
                test.verifyError(@() prodserver.mcp.build("toyToolOne", ...
                    tool=name, folder=test.tempFolder, stop="Definition", ...
                    app=appFile), "prodserver:mcp:ReservedToolName", name);
                test.verifyError(@() prodserver.mcp.build("toyToolOne", ...
                    tool=name, folder=test.tempFolder, stop="Definition"), ...
                    "prodserver:mcp:ReservedToolName", name + " without app");
            end
            % Among several tools, too.
            test.verifyError(@() prodserver.mcp.build( ...
                ["toyToolOne", "toyToolTwo"], tool=["one", "uri2json"], ...
                folder=test.tempFolder, stop="Definition"), ...
                "prodserver:mcp:ReservedToolName");
        end

        function tReservedFunctionNames(test)
        % A function with a reserved name can't be built under any tool
        % name: build would find the framework's function in its place.
        % Checked before the function is looked for, so no such file is
        % needed (one on the path would shadow the framework's).
            for fcn = ["uri2json", "read_mcp_resource", "src/uri2json.m"]
                for toolArg = {{}, {"tool", "other"}}
                    try
                        prodserver.mcp.build(fcn, toolArg{1}{:}, ...
                            folder=test.tempFolder, stop="Definition");
                        test.verifyFail("Expected ReservedToolName for " + fcn);
                    catch me
                        test.verifyEqual(string(me.identifier), ...
                            "prodserver:mcp:ReservedToolName", me.message);
                        test.verifySubstring(me.message, "Rename the function");
                    end
                end
            end
            % A reserved tool name for an ordinary function says to choose
            % another tool name.
            try
                prodserver.mcp.build("toyToolOne", tool="uri2json", ...
                    folder=test.tempFolder, stop="Definition");
                test.verifyFail("Expected ReservedToolName.");
            catch me
                test.verifySubstring(me.message, "'tool' option");
            end
        end

    end

    methods (Access = private)
        function appFile = writeAppFile(test)
            appFile = fullfile(test.tempFolder, "mcp-app.html");
            fid = fopen(appFile, "w");
            fprintf(fid, "<html><body>test</body></html>");
            fclose(fid);
        end
    end

end
