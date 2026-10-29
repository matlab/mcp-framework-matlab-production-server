classdef tPostEncodeSharedFields < matlab.unittest.TestCase
% Test the field-name restoration that every protocol revision shares,
% through prodserver.mcp.protocol.Adapter.postEncode.
%
% This replaces tRestoreJSONFieldsV20250618, which tested a one-row table in
% +v20250618. That row was the UI extension, which is not versioned with the
% protocol -- its constants sit on MCPConstants with the other
% revision-neutral names -- so 2025-06-18 restored it, 2026-07-28 restored
% nothing, and a UI extension block went out mangled on the newer revision.
% The table moved to the base class; this suite is the guard that it applies
% everywhere.
%
% Parameterized over the registry rather than over a hand-written list, so a
% third revision is covered the day its adapter appears in the namespace. A
% revision that forgets to chain to the superclass in its own postEncode
% override fails here instead of shipping a mangled field name.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % Filled in by registeredVersions below. Declared without a value:
        % a TestParameterDefinition method must match a parameterization
        % property declared in the same class, and giving it one here would
        % be a second, stale list of the revisions.
        version
    end

    properties (Constant, Access = private)
        SC = prodserver.mcp.MCPConstants
    end

    methods (Static, TestParameterDefinition)

        function version = registeredVersions()
            vs = prodserver.mcp.protocol.ProtocolRegistry.instance( ...
                ).supportedVersions();
            version = struct();
            for v = reshape(vs, 1, [])
                version.(matlab.lang.makeValidName("v" + v)) = v;
            end
        end

    end

    methods (Access = private)

        function json = encode(test, version, json)
            adapter = prodserver.mcp.protocol.ProtocolRegistry.instance( ...
                ).lookup(version);
            json = adapter.postEncode(json);
        end

    end

    methods (Test)

        function tReplacesUIExtensionField(test, version)
            json = test.encode(version, '{"io_mcp_ui_extension":{"type":"html"}}');
            test.verifyTrue(contains(json, test.SC.UIExtension_JSON), ...
                version + " did not restore the UI extension wire name");
            test.verifyFalse(contains(json, test.SC.UIExtension_Field), ...
                version + " left the mangled UI extension name on the wire");
        end

        function tReplacesMultipleOccurrences(test, version)
            json = test.encode(version, ...
                '{"io_mcp_ui_extension":"a","nested":{"io_mcp_ui_extension":"b"}}');
            test.verifyEqual(count(string(json), test.SC.UIExtension_JSON), 2);
            test.verifyFalse(contains(json, test.SC.UIExtension_Field));
        end

        function tPreservesUnrelatedContent(test, version)
            json = '{"name":"myTool","description":"a tool"}';
            test.verifyEqual(test.encode(version, json), json);
        end

        function tEmptyStringReturnsEmpty(test, version)
            test.verifyEqual(test.encode(version, ''), '');
        end

        function tLeavesFieldNameInValue(test, version)
            % Only keys are renamed -- matched after { or , and before a
            % colon -- so the same text in a string value stays, at no
            % decode/encode cost.
            json = test.encode(version, ...
                '{"description":"see io_mcp_ui_extension docs"}');
            test.verifyFalse(contains(json, test.SC.UIExtension_JSON));
        end

    end

end
