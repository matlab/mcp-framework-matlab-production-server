classdef tJSONEncodingCI < MCPCaller
% Test deployment and invocation of MCP tools built with encoding="JSON".
% Verifies that prodserver.mcp.call sends bare JSON (no typed wrappers) and
% the server responds with bare JSON when the tool uses JSON encoding.

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);
            setFolders(test, temp=tfolder.Folder);
        end
    end

    methods (Test)

        function scalarDouble(test)
            fcn = "toyScalarOne";
            archive = "jsonEncScalar";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            x = 41;
            expected = toyScalarOne(x);
            actual = prodserver.mcp.call(endpoint, fcn, x);

            test.verifyEqual(actual, expected);
        end

        function multiOutput(test)
            fcn = "toyToolOne";
            archive = "jsonEncMultiOut";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, wrapper="None", encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            a = 3; b = uint64(5);
            [eX, eY, eZ] = toyToolOne(a, b);
            [aX, aY, aZ] = prodserver.mcp.call(endpoint, fcn, a, b);

            test.verifyEqual(aX, double(eX), AbsTol=1e-10);
            test.verifyEqual(aY, double(eY), AbsTol=1e-10);
            test.verifyEqual(aZ, double(eZ), AbsTol=1e-10);
        end

        function scalarFourInputs(test)
            fcn = "toyScalarFour";
            archive = "jsonEncFourIn";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            a = 1103515245; c = 12345; m = 2^31; x0 = 7;
            expected = toyScalarFour(a, c, m, x0);
            actual = prodserver.mcp.call(endpoint, fcn, a, c, m, x0);

            test.verifyEqual(actual, expected);
        end

        function stringOutput(test)
            fcn = "toyScalarTwo";
            archive = "jsonEncString";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            % toyScalarTwo uses randi internally so results are
            % non-deterministic. Verify structural properties instead.
            s = "hello world"; n = 3;
            [aCS, aD] = prodserver.mcp.call(endpoint, fcn, s, n);

            test.verifyTrue(ischar(aCS) || isstring(aCS));
            test.verifyEqual(strlength(string(aCS)), strlength(s));
            test.verifyClass(aD, "double");
            test.verifyGreaterThanOrEqual(aD, 0);
        end

        function optionalPositional(test)
            fcn = "toyScalarOptions";
            archive = "jsonEncOptPos";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            % Call with all arguments
            args = {1999, 1001, 100000, "Polaris", "Zeta"};
            expected = feval(fcn, args{:});
            actual = prodserver.mcp.call(endpoint, fcn, args{:});
            test.verifyEqual(string(actual), expected, "All args");

            % Call with only required argument
            expected = feval(fcn, 1999);
            actual = prodserver.mcp.call(endpoint, fcn, 1999);
            test.verifyEqual(string(actual), expected, "Required only");
        end

        function optionalNVP(test)
            fcn = "toyScalarNVOptions";
            archive = "jsonEncOptNVP";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            % Call with NVP arguments
            year = 2020;
            expected = feval(fcn, year, mpg=50, make="Tesla");
            actual = prodserver.mcp.call(endpoint, fcn, year, ...
                'mpg', 50, 'make', "Tesla");
            test.verifyEqual(string(actual), expected, "With NVP");

            % Required only
            expected = feval(fcn, year);
            actual = prodserver.mcp.call(endpoint, fcn, year);
            test.verifyEqual(string(actual), expected, "Required only");
        end

        function multiToolArchive(test)
            fcns = ["toyScalarOne", "toyScalarFour"];
            archive = "jsonEncMultiTool";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcns, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcns(1), "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcns(1) + " not found at " + endpoint);

            % Call first tool
            x = 99;
            expected = toyScalarOne(x);
            actual = prodserver.mcp.call(endpoint, fcns(1), x);
            test.verifyEqual(actual, expected, "toyScalarOne");

            % Call second tool
            a = 7; c = 3; m = 100; x0 = 42;
            expected = toyScalarFour(a, c, m, x0);
            actual = prodserver.mcp.call(endpoint, fcns(2), a, c, m, x0);
            test.verifyEqual(actual, expected, "toyScalarFour");
        end

        function schemaNoAnnotation(test)
            % Verify that JSON-encoded tools do NOT have wire encoding
            % instructions in their description.
            import prodserver.mcp.MCPConstants

            fcn = "toyScalarOne";
            archive = "jsonEncNoAnnot";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            % List tools and check description
            [session, id] = prodserver.mcp.internal.initialize(endpoint, ...
                require="Tool");
            [items, ~] = prodserver.mcp.internal.list(endpoint, session, ...
                "Tool", id=id);
            prodserver.mcp.internal.terminate(endpoint, session);

            tools = items.tools;
            if isstruct(tools)
                tools = num2cell(tools);
            end
            names = cellfun(@(t)string(t.name), tools);
            t = tools{strcmp(names, fcn)};

            test.verifyFalse(contains(string(t.description), ...
                MCPConstants.WireEncodingResourceURI), ...
                "JSON tool should not reference wire encoding resource");
        end

        function schemaVectorJSON(test)
            % Vector data via JSON encoding — orientation is not preserved
            % but values round-trip correctly.
            fcn = "schemaVectorNoBlock";
            archive = "jsonEncVector";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());

            defs = prodserver.mcp.schema(fcn, ...
                @() schemaVectorNoBlock([1,2,3,4,5]));
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            v = [10, 20, 30, 40, 50];
            [eMag, eNorm, eCount] = schemaVectorNoBlock(v);
            [aMag, aNorm, aCount] = prodserver.mcp.call(endpoint, fcn, v);

            test.verifyEqual(aMag, eMag, AbsTol=1e-12);
            test.verifyEqual(aCount, eCount);
            % JSON loses orientation — compare values only
            test.verifyEqual(sort(aNorm(:)), sort(eNorm(:)), AbsTol=1e-12);
        end

        function schemaDurationJSON(test)
            fcn = "schemaDurationNoBlock";
            archive = "jsonEncDuration";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());

            defs = prodserver.mcp.schema(fcn, ...
                @() schemaDurationNoBlock(1, 30, 45));
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            h = 2; m = 15; s = 30;
            [~, eTotalSec] = schemaDurationNoBlock(h, m, s);
            [~, aTotalSec] = prodserver.mcp.call(endpoint, fcn, h, m, s);

            % Duration scalars may degrade to numeric in JSON encoding
            test.verifyEqual(double(aTotalSec), double(eTotalSec), AbsTol=1e-10);
        end

        function schemaDatetimeJSON(test)
            fcn = "schemaDatetimeNoBlock";
            archive = "jsonEncDatetime";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());

            defs = prodserver.mcp.schema(fcn, ...
                @() schemaDatetimeNoBlock(2026, 8, 18));
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            year = 2026; month = 8; day = 18;
            [~, eDow, eSerial] = schemaDatetimeNoBlock(year, month, day);
            [~, aDow, aSerial] = prodserver.mcp.call(...
                endpoint, fcn, year, month, day);

            % Day-of-week is a string — should come back as a char because
            % jsonencode is not Invertible.
            test.verifyEqual(aDow, char(eDow));
            % Serial date number is numeric — should round-trip
            test.verifyEqual(double(aSerial), double(eSerial), AbsTol=1e-10);
        end

        function hybridEncoding(test)
            % Smoke test for Hybrid encoding mode — should behave like
            % Invertible (typed wrappers) for now.
            fcn = "toyScalarOne";
            archive = "jsonEncHybrid";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="Hybrid");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            x = 77;
            expected = toyScalarOne(x);
            actual = prodserver.mcp.call(endpoint, fcn, x);

            test.verifyEqual(actual, expected);
        end

    end
end
