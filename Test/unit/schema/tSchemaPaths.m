classdef tSchemaPaths < matlab.unittest.TestCase
% The declared path (mcpDefinition) and the example path
% (prodserver.mcp.schema) give the same schema for the same declaration.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    properties (TestParameter)
        encoding = {"JSON", "Invertible"}
    end

    methods (Test)

        function textAndCells(test, encoding)
            % z is optional, and the example doesn't pass it.
            example = prodserver.mcp.schema("schemaTextCell", ...
                @() schemaTextCell('ab', 'cd', {1}, ['abc'; 'def']), ...
                encoding=encoding);
            declared = prodserver.mcp.internal.mcpDefinition( ...
                "schemaTextCell", "schemaTextCell", encoding=encoding);
            e = example.tools.inputSchema.properties;
            d = declared.tools.inputSchema.properties;
            for name = ["s" "t" "x" "m" "z"]
                test.verifyEqual(withoutDescription(e.(name)), ...
                    withoutDescription(d.(name)), name);
            end
            % And what that schema is.
            data = @(p) unwrap(p, encoding);
            test.verifyEqual(data(e.s).type, "string", "s");
            test.verifyEqual(data(e.t).type, "string", "t");
            test.verifyEqual(data(e.x).type, "array", "x: a JSON type");
            test.verifyEqual(data(e.z).type, "array", "z: a JSON type");
            test.verifyEqual(data(e.m).type, "array", "m: several rows");
        end

        function charText(test)
            in = prodserver.mcp.internal.metafunction("schemaTextCell").Signature.Inputs;
            f = @prodserver.mcp.jsonrpc.isCharText;
            test.verifyTrue(f("char", in(1).Validation.Size), "(1,:)");
            test.verifyTrue(f("char", []), "no size");
            test.verifyFalse(f("char", in(4).Validation.Size), "(2,3)");
            test.verifyFalse(f("string", []), "string");
        end

    end
end

function s = withoutDescription(s)
    s = rmfield(s, intersect(fieldnames(s), {'description'}));
end

function s = unwrap(s, encoding)
    if encoding == "Invertible"
        [~, s] = prodserver.mcp.test.wrapperOf(s);
    end
end
