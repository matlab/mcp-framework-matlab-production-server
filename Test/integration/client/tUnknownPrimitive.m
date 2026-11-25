classdef tUnknownPrimitive < MockCaller
% prodserver.mcp.call of a tool, or prodserver.mcp.read of a resource, the
% server doesn't list is UnknownTool or UnknownResource, and says what the
% server has. One the server lists twice is NonUniqueTool or
% NonUniqueResource.
%
% Both cases used to be NonUnique..., saying "must exist and have unique
% names. Found 0 ...", which sent a user with a typo looking for
% duplicates.

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function clearProtocolCache(~)
            prodserver.mcp.client.Adapter.create(action="clearAll");
        end
    end

    methods (Test)

        function unknownToolListsTheTools(test)
            endpoint = startMcpServer(test, "tUnknownPrimitive.yaml");
            err = captureError(@() prodserver.mcp.call(endpoint, "foo_bar", 1), 1);
            test.assertNotEmpty(err, "Expected UnknownTool.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:UnknownTool", err.message);
            test.verifySubstring(err.message, "'foo_bar'");
            test.verifySubstring(err.message, endpoint);
            test.verifySubstring(err.message, "Its tools are: dup, f1, f2.");
            test.verifyFalse(contains(err.message, "unique"), err.message);
        end

        function existOnAnEmptyServerIsFalse(test)
        % A server with no tools or resources lists none. Neither exists;
        % the empty list used to make exist raise an error instead.
            endpoint = startMcpServer(test, "tUnknownPrimitive.yaml");
            endpoint = replace(endpoint, "/mcp", "/empty/mcp");
            tf = prodserver.mcp.exist(endpoint, ["f1", "mcp://jdoe/data"], ...
                ["Tool", "Resource"]);
            test.verifyEqual(tf, [false false]);
        end

        function duplicateToolIsNonUnique(test)
            endpoint = startMcpServer(test, "tUnknownPrimitive.yaml");
            err = captureError(@() prodserver.mcp.call(endpoint, "dup", 1), 1);
            test.assertNotEmpty(err, "Expected NonUniqueTool.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:NonUniqueTool", err.message);
            test.verifySubstring(err.message, "2 tools named 'dup'");
        end

        function unknownResourceListsTheResources(test)
            endpoint = startMcpServer(test, "tUnknownPrimitive.yaml");
            err = captureError(@() prodserver.mcp.read(endpoint, "mcp://nope"), 1);
            test.assertNotEmpty(err, "Expected UnknownResource.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:UnknownResource", err.message);
            test.verifySubstring(err.message, "'mcp://nope'");
            test.verifySubstring(err.message, ...
                "Its resources are: mcp://jdoe/data, mcp://jdoe/dup, mcp://jdoe/notes.");
        end

        function duplicateResourceIsNonUnique(test)
            endpoint = startMcpServer(test, "tUnknownPrimitive.yaml");
            err = captureError(@() prodserver.mcp.read(endpoint, "mcp://jdoe/dup"), 1);
            test.assertNotEmpty(err, "Expected NonUniqueResource.");
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:NonUniqueResource", err.message);
            test.verifySubstring(err.message, "2 resources with URI 'mcp://jdoe/dup'");
        end

        function longListsAreCut(test)
            names = "t" + string(1:14);
            txt = prodserver.mcp.internal.availableList("tools", names);
            test.verifySubstring(txt, ", and 4 more.");
            test.verifyEqual(prodserver.mcp.internal.availableList("tools", ...
                string.empty), "It has no tools.");
        end

    end

end
