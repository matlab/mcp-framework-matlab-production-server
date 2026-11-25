classdef tClientCapabilities < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.ClientCapabilities.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        UI = "io.modelcontextprotocol/ui"
        AppMime = "text/html;profile=mcp-app"
    end

    methods (Test)

        function tExtensionFromJSON(test)
        % An extension declared in real JSON is found by its spec ID, through
        % jsondecode's renaming.
            caps = fromJSON(['{"extensions":{"io.modelcontextprotocol/ui":' ...
                '{"mimeTypes":["text/html;profile=mcp-app"]}}}']);
            test.verifyTrue(supports(caps, test.UI));
            settings = extension(caps, test.UI);
            test.verifyEqual(string(settings.mimeTypes), test.AppMime);
        end

        function tExtensionWithoutSettings(test)
        % {} declares support with no settings.
            caps = fromJSON('{"extensions":{"io.modelcontextprotocol/tasks":{}}}');
            test.verifyTrue(supports(caps, "io.modelcontextprotocol/tasks"));
            settings = extension(caps, "io.modelcontextprotocol/tasks");
            test.verifyClass(settings, "struct");
            test.verifyEmpty(fieldnames(settings));
        end

        function tUndeclaredExtension(test)
            caps = fromJSON('{"extensions":{"io.modelcontextprotocol/tasks":{}}}');
            test.verifyFalse(supports(caps, test.UI));
            test.verifyEqual(extension(caps, test.UI), []);
        end

        function tNoExtensionsField(test)
            caps = fromJSON('{"roots":{"listChanged":true}}');
            test.verifyFalse(supports(caps, test.UI));
        end

        function tCoreCapabilities(test)
        % Declared core capabilities keep their settings; undeclared ones
        % are [].
            caps = fromJSON('{"roots":{"listChanged":true},"sampling":{}}');
            test.verifyTrue(caps.Roots.listChanged);
            test.verifyClass(caps.Sampling, "struct");
            test.verifyEmpty(fieldnames(caps.Sampling));
            test.verifyEqual(caps.Elicitation, []);
            test.verifyEqual(caps.Experimental, []);
        end

        function tNone(test)
            caps = prodserver.mcp.protocol.ClientCapabilities.none();
            test.verifyFalse(supports(caps, test.UI));
            test.verifyEqual(caps.Roots, []);
            test.verifyEqual(caps.Sampling, []);
        end

        function tMalformedDeclarations(test)
        % A declaration that isn't a JSON object declares nothing; so do
        % extensions that aren't an object.
            import prodserver.mcp.protocol.ClientCapabilities
            for bad = {5, "x", [], struct("a", {1, 2})}
                caps = ClientCapabilities(bad{1});
                test.verifyFalse(supports(caps, test.UI));
            end
            caps = fromJSON('{"extensions":["io.modelcontextprotocol/ui"]}');
            test.verifyFalse(supports(caps, test.UI));
        end

        function tCollision(test)
        % Two IDs that jsondecode renames to the same field name: the first
        % is found by its ID, as the class documents.
            caps = fromJSON(['{"extensions":{"io.modelcontextprotocol/ui":{},' ...
                '"io_modelcontextprotocol_ui":{}}}']);
            test.verifyTrue(supports(caps, test.UI));
        end

    end
end

function caps = fromJSON(json)
    caps = prodserver.mcp.protocol.ClientCapabilities(jsondecode(json));
end
