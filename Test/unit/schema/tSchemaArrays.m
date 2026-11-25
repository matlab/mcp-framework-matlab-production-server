classdef tSchemaArrays < matlab.unittest.TestCase
%tSchemaArrays Verify that a %#schema's lists keep their members.
%   jsondecode stacks a JSON array's elements into one MATLAB array when it
%   can: "enum": [1, 2, 3] becomes the column [1;2;3], and "enum": [5] the
%   scalar 5. An enum's members must stay separate for the validator to
%   compare an argument with each one, and enum and examples must be
%   published as JSON arrays, as JSON Schema requires.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        % unstackDecodedArray

        function unstackEachDecodedForm(test)
            f = @(j) prodserver.mcp.jsonrpc.unstackDecodedArray(jsondecode(j));
            test.verifyEqual(f('[1, 2, 3]'), {1; 2; 3}, "numbers");
            test.verifyEqual(f('[true, false]'), {true; false}, "booleans");
            test.verifyEqual(f('[5]'), {5}, "one number");
            test.verifyEqual(f('[[1, 2], [3, 4]]'), {[1; 2]; [3; 4]}, ...
                "rows, as jsondecode gives each alone");
            test.verifyEqual(f('[[1, 2]]'), {[1 2]}, "one array");
            test.verifyEqual(f('[[[1, 2], [3, 4]], [[5, 6], [7, 8]]]'), ...
                {[1 2; 3 4]; [5 6; 7 8]}, "slices of a 3-D array");
            test.verifyEqual(f('[{"a": 1}, {"a": 2}]'), ...
                {struct('a', 1); struct('a', 2)}, "objects");
            test.verifyEqual(f('[[{"a": 1}, {"a": 2}]]'), ...
                {jsondecode('[{"a": 1}, {"a": 2}]')'}, "one array of objects");
            test.verifyEqual(f('[1, "a"]'), {1; 'a'}, "mixed: a cell already");
            test.verifyEqual(f('["a"]'), {'a'}, "one string");
            test.verifyEqual(f('[]'), cell(0, 1), "empty");
            test.verifyEqual(f('[1, null]'), {1; NaN}, "null among numbers");
        end

        function unstackMATLABLists(test)
            f = @prodserver.mcp.jsonrpc.unstackDecodedArray;
            test.verifyEqual(f({"a", "b"}), {"a"; "b"});
            test.verifyEqual(f(["a" "b"]), {"a"; "b"});
            test.verifyEqual(f('abc'), {'abc'});
        end

        % unstackSchemaLists

        function unstackEnumAndExamplesAtAnyDepth(test)
            s = prodserver.mcp.jsonrpc.unstackSchemaLists(jsondecode( ...
                ['{"enum": [1, 2], "items": {"examples": [5]}, ' ...
                 '"anyOf": [{"enum": [true]}, {"type": "null"}], ' ...
                 '"properties": {"p": {"enum": [3]}}}']));
            test.verifyEqual(s.enum, {1; 2});
            test.verifyEqual(s.items.examples, {5});
            test.verifyEqual(s.anyOf{1}.enum, {true});
            test.verifyEqual(s.properties.p.enum, {3});
        end

        function unstackLeavesDataAndNamesAlone(test)
            s = prodserver.mcp.jsonrpc.unstackSchemaLists(jsondecode( ...
                ['{"default": {"enum": [1, 2]}, "const": [1, 2], ' ...
                 '"properties": {"enum": {"type": "number"}, ' ...
                 '"examples": {"type": "string"}}}']));
            test.verifyEqual(s.default.enum, [1; 2], "default is data");
            test.verifyEqual(s.const, [1; 2], "const is data");
            test.verifyEqual(s.properties.enum, struct('type', 'number'), ...
                "a property named enum");
            test.verifyEqual(s.properties.examples, ...
                struct('type', 'string'), "a property named examples");
        end

        % Validation

        function enumMembersAccepted(test)
            cases = {
                '[1, 2, 3]',            2
                '[true, false]',        false
                '[5]',                  5
                '["fast", "slow"]',     'slow'
                '[1, "a"]',             'a'
                '[[1, 2], [3, 4]]',     [3; 4]
                '[[1, 2]]',             [1; 2]
                '[{"a": 1}, {"a": 2}]', struct('a', 2)
                '[1, null]',            []
                };
            for k = 1:size(cases, 1)
                test.verifyEqual(enumDetail(cases{k,:}), "", cases{k,1});
                test.verifyEqual(enumDetail(cases{k,:}, true), "", ...
                    cases{k,1} + " through unstackSchemaLists");
            end
        end

        function enumNonMembersRejected(test)
            cases = {
                '[1, 2, 3]',            4,              "value 4 is not one of 1, 2, 3"
                '[true]',               false,          "value false is not one of true"
                '["fast", "slow"]',     'medium',       'value "medium" is not one of "fast", "slow"'
                '[[1, 2], [3, 4]]',     [1; 3],         "value [1,3] is not one of [1,2], [3,4]"
                '[{"a": 1}, {"a": 2}]', struct('a', 3), 'value {"a":3} is not one of {"a":1}, {"a":2}'
                };
            for k = 1:size(cases, 1)
                for unstacked = [false true]
                    test.verifyEqual(enumDetail(cases{k,1:2}, unstacked), ...
                        string(cases{k,3}), cases{k,1});
                end
            end
        end

        function constComparedAsDecoded(test)
            % A const and an argument both come from jsondecode, in the
            % same form, so const needs no unstacking.
            f = @(j, v) prodserver.mcp.validation.validateArgumentsWithSchema( ...
                struct('properties', struct('x', jsondecode(j))), "x", {v});
            test.verifyEqual(f('{"const": 1}', 1), "");
            test.verifyEqual(f('{"const": [1]}', jsondecode('[1]')), "");
            test.verifyEqual(f('{"const": [1, 2]}', jsondecode('[1, 2]')), "");
            test.verifyEqual(f('{"const": [[1, 2]]}', jsondecode('[[1, 2]]')), "");
            test.verifyGreaterThan(strlength( ...
                f('{"const": [1, 2]}', jsondecode('[1, 3]'))), 0);
        end

        % Built and published schemas

        function enumsAndExamplesPublishedAsArrays(test)
            for enc = ["JSON" "Invertible"]
                p = publishedInputs(enc);
                test.verifySubstring(p.level, '"enum":[1,2,3]', enc);
                test.verifySubstring(p.flag, '"enum":[true]', enc);
                test.verifySubstring(p.mode, '"enum":["fast","slow"]', enc);
                test.verifySubstring(p.pair, '"enum":[[1,2],[3,4]]', enc);
                test.verifySubstring(p.pair, '"examples":[[1,2]]', enc);
                % One-element arrays are their elements in MATLAB.
                test.verifySubstring(p.counts, '"default":5', enc);
                test.verifySubstring(p.counts, '"examples":[5,[6,7]]', enc);
            end
        end

        function builtEnumsAcceptMembers(test)
            % JSON: the value itself. Invertible: the wrapper, whose data
            % element carries the enum.
            d = prodserver.mcp.internal.mcpDefinition("schemaEnums", ...
                "schemaEnums", encoding="JSON");
            f = @(a) prodserver.mcp.validation.toolArgumentError(d.tools, a, ...
                prodserver.mcp.WireEncoding.JSON);
            test.verifyEqual(f(struct('level', 2)), "");
            test.verifyEqual(f(struct('flag', true)), "");
            test.verifyEqual(f(struct('pair', [3; 4])), "");
            test.verifySubstring(f(struct('level', 4)), "is not one of");
            test.verifySubstring(f(struct('pair', [1; 3])), "is not one of");

            d = prodserver.mcp.internal.mcpDefinition("schemaEnums", ...
                "schemaEnums", encoding="Invertible");
            f = @(a) prodserver.mcp.validation.toolArgumentError(d.tools, a, ...
                prodserver.mcp.WireEncoding.Invertible);
            w = @(sz, v) struct('type', "double", 'size', sz, 'data', v);
            test.verifyEqual(f(struct('level', w([1 1], 2))), "");
            test.verifyGreaterThan(strlength(f(struct('level', w([1 1], 4)))), 0);
            test.verifyEqual(f(struct('pair', w([1 2], [1; 2]))), "");
            test.verifySubstring(f(struct('pair', w([1 2], [1; 3]))), ...
                "is not one of");
        end

    end
end

function detail = enumDetail(enumJSON, value, unstacked)
% Validate VALUE against {"enum": ENUMJSON}, as jsondecode gives it, or if
% UNSTACKED, as the build stores it.
    s = jsondecode(['{"enum": ' enumJSON '}']);
    if nargin > 2 && unstacked
        s = prodserver.mcp.jsonrpc.unstackSchemaLists(s);
    end
    detail = prodserver.mcp.validation.validateArgumentsWithSchema( ...
        struct('properties', struct('x', s)), "x", {value});
end

function p = publishedInputs(encoding)
% Each input of schemaEnums, as tools/list publishes it, without its
% description.
    d = prodserver.mcp.internal.mcpDefinition("schemaEnums", ...
        "schemaEnums", encoding=encoding);
    props = d.tools.inputSchema.properties;
    p = struct();
    for n = string(fieldnames(props))'
        s = props.(n);
        if isfield(s, 'description')
            s = rmfield(s, 'description');
        end
        p.(n) = jsonencode(s);
    end
end
