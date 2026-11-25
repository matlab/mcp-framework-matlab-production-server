classdef tParentSelection < matlab.unittest.TestCase
% W3C trace context and parent selection: prodserver.mcp.internal.TraceContext
% (F4). One test per row of the foundations design's parent-selection.yaml,
% then the parsing rules of its trace-context.schema.json.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Meta = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        Other = "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01"
        Bad = "ff-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    end

    methods (Test)

        % ---- parent-selection.yaml, one row each (FND-36)

        function metaAbsentHeaderAbsentParentIsInvalid(test)
            verifyRow(test, "", "", "root", false);
        end

        function metaAbsentHeaderValidParentIsHeader(test)
            verifyRow(test, "", test.Meta, "header", false);
        end

        function metaAbsentHeaderOtherParentIsHeader(test)
            verifyRow(test, "", test.Other, "header", false);
        end

        function metaAbsentHeaderInvalidParentIsInvalid(test)
            verifyRow(test, "", test.Bad, "root", false);
        end

        function metaValidHeaderAbsentParentIsMeta(test)
            verifyRow(test, test.Meta, "", "meta", false);
        end

        function metaValidHeaderValidParentIsMeta(test)
            verifyRow(test, test.Meta, test.Meta, "meta", false);
        end

        function metaValidHeaderOtherParentIsMetaAndLinked(test)
            verifyRow(test, test.Meta, test.Other, "meta", true);
        end

        function metaValidHeaderInvalidParentIsMeta(test)
            verifyRow(test, test.Meta, test.Bad, "meta", false);
        end

        function metaInvalidHeaderAbsentParentIsInvalid(test)
            verifyRow(test, test.Bad, "", "root", false);
        end

        function metaInvalidHeaderValidParentIsHeader(test)
            verifyRow(test, test.Bad, test.Meta, "header", false);
        end

        function metaInvalidHeaderOtherParentIsHeader(test)
            verifyRow(test, test.Bad, test.Other, "header", false);
        end

        function metaInvalidHeaderInvalidParentIsInvalid(test)
            verifyRow(test, test.Bad, test.Bad, "root", false);
        end

        % ---- validity (FND-37, FND-25)

        function everyExampleParsesAsTheSchemaSays(test)
            % The examples of the foundations design's trace-context.schema.json.
            T = "4bf92f3577b34da6a3ce929d0e0e4736";
            P = "00f067aa0ba902b7";
            valid = ["00-" + T + "-" + P + "-01", "01-" + T + "-" + P + "-01"];
            invalid = ["ff-" + T + "-" + P + "-01", ...
                "00-" + repmat('0', 1, 32) + "-" + P + "-01", ...
                "00-" + T + "-" + repmat('0', 1, 16) + "-01", ...
                "00-" + upper(T) + "-" + P + "-01", ...
                "00-" + extractBefore(T, 31) + "-" + P + "-01"];
            for v = valid
                tc = prodserver.mcp.internal.TraceContext(v);
                test.verifyTrue(tc.IsValid, v);
                test.verifyEqual(tc.TraceId, T, v);
                test.verifyEqual(tc.SpanId, P, v);
                test.verifyEqual(tc.TraceParent, v, v);
            end
            for v = invalid
                tc = prodserver.mcp.internal.TraceContext(v);
                test.verifyFalse(tc.IsValid, v);
                test.verifyEqual([tc.TraceParent, tc.TraceState, tc.TraceId, tc.SpanId], ...
                    ["", "", "", ""], v);
            end
            withState = prodserver.mcp.internal.TraceContext(valid(1), ...
                "rojo=00f067aa0ba902b7,congo=t61rcWkgMzE");
            test.verifyEqual(withState.TraceState, "rojo=00f067aa0ba902b7,congo=t61rcWkgMzE");
            upperKey = prodserver.mcp.internal.TraceContext(valid(1), "Rojo=00f067aa0ba902b7");
            test.verifyTrue(upperKey.IsValid);
            test.verifyEqual(upperKey.TraceState, "");
        end

        function invalidInputNeverRaises(test)
            inputs = {42, struct("a", 1), ["a"; "b"], string(missing), ...
                repmat('a', 1, 10e6), "00-" + newline + "x", {test.Meta}, []};
            for k = 1:numel(inputs)
                tc = prodserver.mcp.internal.TraceContext(inputs{k});
                test.verifyFalse(tc.IsValid, "traceparent input " + k);
                tc = prodserver.mcp.internal.TraceContext(test.Meta, inputs{k});
                test.verifyTrue(tc.IsValid, "tracestate input " + k);
                test.verifyEqual(tc.TraceState, "", "tracestate input " + k);
            end
        end

        function futureVersionIsAccepted(test)
            tc = prodserver.mcp.internal.TraceContext( ...
                "01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01");
            test.verifyTrue(tc.IsValid);
        end

        function futureVersionWithMoreFieldsIsRejected(test)
            % W3C lets a parser accept a later version's extra fields; this
            % one accepts only the four (FA-19).
            tc = prodserver.mcp.internal.TraceContext( ...
                "01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01-extra");
            test.verifyFalse(tc.IsValid);
            test.verifyEqual(tc.TraceParent, "");
        end

        % ---- tracestate (FND-38)

        function tracestateComesFromTheWinningCarrier(test)
            meta = prodserver.mcp.internal.TraceContext(test.Meta, "rojo=1");
            header = prodserver.mcp.internal.TraceContext(test.Meta, "congo=2");
            parent = prodserver.mcp.internal.TraceContext.select(meta, header);
            test.verifyEqual(parent.TraceState, "rojo=1");
        end

        function invalidTracestateIsDroppedParentKept(test)
            tc = prodserver.mcp.internal.TraceContext(test.Meta, "Rojo=1");
            test.verifyTrue(tc.IsValid);
            test.verifyEqual(tc.TraceState, "");
            tooMany = join("k" + (1:33) + "=v", ",");
            tc = prodserver.mcp.internal.TraceContext(test.Meta, tooMany);
            test.verifyTrue(tc.IsValid);
            test.verifyEqual(tc.TraceState, "", "more than 32 members");
        end

        function tracestateWithALineBreakIsDropped(test)
            % Stripping each member must not let a line break between two
            % members through: the value would go on into a header.
            for sep = ["\r\n", "\n", "\v", "\f", char(8232)]
                state = "a=b," + compose(sep) + "c=d";
                tc = prodserver.mcp.internal.TraceContext(test.Meta, state);
                test.verifyTrue(tc.IsValid);
                test.verifyEqual(tc.TraceState, "", state);
            end
        end

        function tracestateMayHaveSpacesAndTabsAroundMembers(test)
            tc = prodserver.mcp.internal.TraceContext(test.Meta, "a=b , " + char(9) + "c=d");
            test.verifyEqual(tc.TraceState, "a=b , " + char(9) + "c=d");
        end

        % ---- the carriers and the API (FND-24)

        function fromMetaReadsXMetaOnAnyMessage(test)
            withMeta = struct("jsonrpc", "2.0", "id", 1, "method", "tools/call", ...
                "params", struct("x_meta", struct("traceparent", test.Meta, "tracestate", "rojo=1")));
            tc = prodserver.mcp.internal.TraceContext.fromMeta(withMeta);
            test.verifyTrue(tc.IsValid);
            test.verifyEqual(tc.TraceParent, test.Meta);
            test.verifyEqual(tc.TraceState, "rojo=1");
            noMeta = struct("jsonrpc", "2.0", "id", 1, "method", "tools/call", "params", struct("name", "x"));
            noParams = struct("jsonrpc", "2.0", "method", "notifications/initialized");
            for jrpc = {noMeta, noParams, [], "not a struct"}
                test.verifyFalse(prodserver.mcp.internal.TraceContext.fromMeta(jrpc{1}).IsValid);
            end
        end

        function fromHeadersMatchesNamesIgnoringCase(test)
            for name = ["traceparent", "TraceParent", "TRACEPARENT"]
                request = struct("Headers", {{'Host', 'x'; char(name), char(test.Meta)}});
                tc = prodserver.mcp.internal.TraceContext.fromHeaders(request);
                test.verifyTrue(tc.IsValid, name);
            end
            test.verifyFalse(prodserver.mcp.internal.TraceContext.fromHeaders(struct("Method", "POST")).IsValid);
            test.verifyFalse(prodserver.mcp.internal.TraceContext.fromHeaders(struct("Headers", {{}})).IsValid);
            test.verifyFalse(prodserver.mcp.internal.TraceContext.fromHeaders( ...
                struct("Headers", {{'a', 'b', 'c'}})).IsValid, "a list that isn't Nx2");
        end

        function fieldsAreTheTextTheFactoriesParse(test)
            import prodserver.mcp.internal.TraceContext
            jrpc = struct("params", struct("x_meta", struct("traceparent", " " + test.Meta, ...
                "tracestate", "rojo=1", "other", 1:1e5)));
            [tp, ts] = TraceContext.metaFields(jrpc);
            test.verifyEqual([tp, ts], [test.Meta, "rojo=1"], "trimmed, and nothing else kept");
            request = struct("Headers", {{'Authorization', 'Bearer secret'; ...
                'traceparent', char(test.Other); 'TraceState', 'congo=2'}});
            [tp, ts] = TraceContext.headerFields(request);
            test.verifyEqual([tp, ts], [test.Other, "congo=2"]);
            for absent = {[], struct("params", 1), "text"}
                [tp, ts] = TraceContext.metaFields(absent{1});
                test.verifyEqual([tp, ts], ["", ""]);
                [tp, ts] = TraceContext.headerFields(absent{1});
                test.verifyEqual([tp, ts], ["", ""]);
            end
        end

        function fieldsLongerThanAnyValidValueAreEmpty(test)
            % "", never cut: a cut value could become a valid one.
            import prodserver.mcp.internal.TraceContext
            long = test.Meta + "-00";
            state = join(repmat("k=" + string(repmat('v', 1, 250)), 1, 3), ",");
            [tp, ts] = TraceContext.metaFields(struct("params", struct("x_meta", ...
                struct("traceparent", long, "tracestate", state))));
            test.verifyEqual([tp, ts], ["", ""]);
            [tp, ts] = TraceContext.headerFields(struct("Headers", ...
                {{'traceparent', char(long); 'tracestate', char(state)}}));
            test.verifyEqual([tp, ts], ["", ""]);
        end

        function textMapCarrierHasTheValidContextOnly(test)
            both = prodserver.mcp.internal.TraceContext(test.Meta, "rojo=1");
            test.verifyEqual(textMapCarrier(both), ["traceparent", test.Meta; "tracestate", "rojo=1"]);
            parentOnly = prodserver.mcp.internal.TraceContext(test.Meta);
            test.verifyEqual(textMapCarrier(parentOnly), ["traceparent", test.Meta]);
            test.verifySize(textMapCarrier(prodserver.mcp.internal.TraceContext()), [0 2]);
        end

        function noOpenTelemetryDependency(test)
            % TraceContext calls nothing from OpenTelemetry-MATLAB, so an
            % archive built without tracing can still use it.
            files = matlab.codetools.requiredFilesAndProducts( ...
                which("prodserver.mcp.internal.TraceContext"));
            test.verifyFalse(any(contains(files, ["+opentelemetry", "+libmexclass"])), ...
                strjoin(files, newline));
        end
    end

    methods (Access = private)
        function verifyRow(test, meta, header, parent, link)
            m = prodserver.mcp.internal.TraceContext(meta);
            h = prodserver.mcp.internal.TraceContext(header);
            [p, l] = prodserver.mcp.internal.TraceContext.select(m, h);
            switch parent
                case "meta"
                    test.verifyEqual(p, m);
                case "header"
                    test.verifyEqual(p, h);
                case "root"
                    test.verifyFalse(p.IsValid);
            end
            test.verifyEqual(l.IsValid, link);
            if link
                test.verifyEqual(l, h);
            end
        end
    end
end
