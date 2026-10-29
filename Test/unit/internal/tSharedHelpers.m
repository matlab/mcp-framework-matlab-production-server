classdef tSharedHelpers < matlab.unittest.TestCase
% Small helpers the framework's messages, responses and schema checks
% share.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function andList(test)
            f = @prodserver.mcp.internal.andList;
            test.verifyEqual(f(string.empty), "");
            test.verifyEqual(f("a"), "a");
            test.verifyEqual(f(["a" "b"]), "a and b");
            test.verifyEqual(f(["a" "b" "c"]), "a, b and c");
        end

        function httpStatus(test)
            f = @prodserver.mcp.handler.internal.httpStatus;
            [code, reason] = f(404);
            test.verifyEqual(code, 404);
            test.verifyEqual(reason, 'Not Found');
            [~, reason] = f(200);
            test.verifyEqual(reason, 'OK');
            test.verifyError(@() f(418), "prodserver:mcp:UnknownHTTPStatus");
        end

        function serverInfo(test)
            import prodserver.mcp.MCPConstants
            s = prodserver.mcp.protocol.serverInfo("archive");
            test.verifyEqual(s, struct('name', MCPConstants.ServerName, ...
                'title', "archive", 'version', MCPConstants.ServerVersion));
            test.verifyFalse(isfield(prodserver.mcp.protocol.serverInfo(), 'title'));
        end

        function capabilitiesNeverChange(test)
            caps = prodserver.mcp.protocol.capabilities();
            for f = string(fieldnames(caps))'
                test.verifyFalse(caps.(f).listChanged, f);
            end
        end

        function rowMajor(test)
            % The order both wire encodings write data in, and back.
            x = reshape(1:24, [2 3 4]) + 1i*reshape(24:-1:1, [2 3 4]);
            for sz = {[1 1], [1 5], [5 1], [2 3], [2 3 4], [0 3]}
                v = x(1:prod(sz{1}));
                v = reshape(v, sz{1});
                idx = prodserver.mcp.jsonrpc.rowMajorOrder(size(v));
                test.verifyEqual(prodserver.mcp.jsonrpc.fromRowMajor(v(idx), size(v)), ...
                    v, mat2str(sz{1}));
            end
            test.verifyEqual(prodserver.mcp.jsonrpc.rowMajorOrder([2 3]), [1 3 5 2 4 6]);
            test.verifyEqual(prodserver.mcp.jsonrpc.fromRowMajor({'a','b','c','d'}, [2 2]), ...
                {'a','b';'c','d'});
        end

        function alternativesAndAnyOf(test)
            a = struct('type', "number"); b = struct('type', "string");
            f = @prodserver.mcp.jsonrpc.schemaAlternatives;
            test.verifyEqual(f(struct('anyOf', {{a, b}})), {a; b});
            test.verifyEqual(f(struct('anyOf', [a b])), {a; b}, "A struct array");
            test.verifyEqual(f(struct('oneOf', {{a}}), "oneOf"), {a});
            test.verifyEqual(f(a), {});
            g = @prodserver.mcp.jsonrpc.anyOfSchema;
            test.verifyEqual(g({a, a}), a);
            test.verifyEqual(g({a, b, a}), struct('anyOf', {{a, b}}));
            test.verifyEqual(g({}), struct());
        end

        function endpointNames(test)
            f = @prodserver.mcp.internal.archiveFromEndpoint;
            test.verifyEqual(f("http://host:9910/myArchive/mcp"), "myArchive");
            test.verifyEqual(f("http://host:9910"), "");
            g = @prodserver.mcp.internal.serverNameFromPath;
            test.verifyEqual(g("/myArchive/mcp"), "myArchive");
            test.verifyEqual(g(struct('Path', "/myArchive/mcp")), "myArchive");
            test.verifyEqual(g(struct('Method', "POST")), "", "A request with no Path");
        end

        function stampMeta(test)
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;
            b = prodserver.mcp.protocol.v20260728.stampMeta(struct('method', "x"));
            test.verifyEqual(b.params.(MCPConstants.MetaField).(C.MetaProtocolVersion_Field), ...
                C.Version);
            test.verifyEqual(b.params.(MCPConstants.MetaField).(C.MetaCapabilities_Field), ...
                struct());
        end

        function schemaPredicates(test)
            import prodserver.mcp.MCPConstants
            dt = prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", ...
                prodserver.mcp.jsonrpc.WireShape.Scalar);
            test.verifyTrue(prodserver.mcp.jsonrpc.isDateTimeSchema(dt));
            test.verifyFalse(prodserver.mcp.jsonrpc.isDateTimeSchema(struct('type', "string")));
            w = prodserver.mcp.jsonrpc.wrapInvertible(struct('type', "number"));
            test.verifyTrue(prodserver.mcp.jsonrpc.isInvertibleSchema(w));
            test.verifyEqual(w.annotation, MCPConstants.InvertibleAnnotation);
            test.verifyFalse(prodserver.mcp.jsonrpc.isInvertibleSchema(dt));
            names = prodserver.mcp.jsonrpc.WireSupport.classNames();
            test.verifyTrue(all(ismember(["double" "datetime" "table"], names)));
        end

    end
end
