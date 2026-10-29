classdef tClassSchema < matlab.unittest.TestCase
% Test prodserver.mcp.jsonrpc.classSchema and
% prodserver.mcp.validation.mustBeWireType: the checked schema of a class
% plain JSON can't describe, for each encoding.

% Copyright 2026 The MathWorks, Inc.

    properties
        Sizes   % schemaWireTimes declares (1,1), (1,:) and (1,3)
    end

    methods (TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
            in = prodserver.mcp.internal.metafunction("schemaWireTimes").Signature.Inputs;
            test.Sizes = {in.Validation};
            test.Sizes = cellfun(@(v) v.Size, test.Sizes, UniformOutput=false);
        end
    end

    methods (Test)

        function invertibleShapes(test)
            import prodserver.mcp.jsonrpc.WireShape
            f = @(varargin) prodserver.mcp.jsonrpc.classSchema("p", "datetime", ...
                prodserver.mcp.WireEncoding.Invertible, varargin{:});
            % A scalar datetime is bare ISO text, or the wrapper when it
            % has a named zone; an array is wrapped.
            s = f(size=test.Sizes{1});
            test.verifyEqual(s.anyOf{1}, struct('type', "string", 'format', "date-time"));
            test.verifyEqual(string(s.anyOf{2}.enum), "NaT");
            test.verifyTrue(isfield(s.anyOf{3}.properties, 'tz'));
            test.verifyEqual(string(f(size=test.Sizes{3}).properties.type.enum), "datetime");
            % Unrestricted, or no size: either form.
            test.verifyEqual(f(size=test.Sizes{2}), s);
            test.verifyEqual(f(), s);
            % With no declared size, the observed shape decides.
            test.verifyEqual(string(f(shape=WireShape.Array).properties.type.enum), "datetime");
            % A scalar duration has its own form.
            d = prodserver.mcp.jsonrpc.classSchema("p", "duration", ...
                prodserver.mcp.WireEncoding.Invertible, shape=WireShape.Scalar);
            test.verifyEqual(string(d.properties.type.enum), "duration");
        end

        function declaredSizeOverridesObservedShape(test)
            import prodserver.mcp.jsonrpc.WireShape
            s = prodserver.mcp.jsonrpc.classSchema("p", "duration", ...
                prodserver.mcp.WireEncoding.Invertible, size=test.Sizes{1}, ...
                shape=WireShape.Array);
            test.verifyEqual(string(s.properties.type.enum), "duration");
            test.verifyFalse(isfield(s.properties, 'size'), ...
                "A scalar duration has no size.");
        end

        function jsonForms(test)
            f = @(varargin) prodserver.mcp.jsonrpc.classSchema("p", varargin{:});
            JSON = prodserver.mcp.WireEncoding.JSON;
            s = f("datetime", JSON, size=test.Sizes{1});
            test.verifyEqual(s.format, "date-time");
            s = f("duration", JSON, size=test.Sizes{3});
            test.verifyEqual(s.type, "array");
            test.verifyEqual([s.minItems s.maxItems], [3 3]);
            s = f("duration", JSON, size=test.Sizes{2});
            test.verifyFalse(isfield(s, 'maxItems'), "Unrestricted has no count.");
        end

        function invertibleOnlyClassesRefusedUnderJSON(test)
            for c = ["categorical" "table" "timetable"]
                test.verifyError(@() prodserver.mcp.jsonrpc.classSchema("p", c, ...
                    prodserver.mcp.WireEncoding.JSON), ...
                    "prodserver:mcp:IncompatibleArgumentType", c);
                s = prodserver.mcp.jsonrpc.classSchema("p", c, ...
                    prodserver.mcp.WireEncoding.Invertible);
                test.verifyEqual(string(s.properties.type.enum), c);
            end
        end

        function unsupportedClassesRefused(test)
            for enc = enumeration("prodserver.mcp.WireEncoding")'
                test.verifyError(@() prodserver.mcp.jsonrpc.classSchema("p", ...
                    "function_handle", enc), ...
                    "prodserver:mcp:IncompatibleArgumentType", string(enc));
            end
        end

        function messageNamesParameterAndClass(test)
            try
                prodserver.mcp.validation.mustBeWireType("rec.when", ...
                    "table", prodserver.mcp.WireEncoding.JSON);
                test.verifyFail("No error");
            catch me
                test.verifySubstring(me.message, "'rec.when'");
                test.verifySubstring(me.message, "'table'");
                test.verifySubstring(me.message, "encoding=""Invertible""");
            end
            try
                prodserver.mcp.validation.mustBeWireType("h", ...
                    "function_handle", prodserver.mcp.WireEncoding.Invertible);
                test.verifyFail("No error");
            catch me
                test.verifySubstring(me.message, ...
                    prodserver.mcp.jsonrpc.WireSupport.supportedClasses());
            end
        end

        function mustBeWireTypeAccepts(test)
            import prodserver.mcp.WireEncoding
            f = @prodserver.mcp.validation.mustBeWireType;
            test.verifyWarningFree(@() f("x", "double", WireEncoding.JSON));
            test.verifyWarningFree(@() f("x", "datetime", WireEncoding.JSON));
            test.verifyWarningFree(@() f("x", "table", WireEncoding.Invertible));
            % A typemap entry maps the class to a JSON type.
            test.verifyWarningFree(@() f("x", "table", WireEncoding.JSON, ...
                struct('table', "object")));
        end

    end
end
