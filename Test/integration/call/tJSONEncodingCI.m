classdef tJSONEncodingCI < prodserver.mcp.test.base.MCPCaller
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

            x = 41;
            expected = toyScalarOne(x);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                actual = prodserver.mcp.call(endpoint, fcn, x);
                test.verifyEqual(actual, expected, "[" + p + "]");
            end
        end

        function multiOutput(test)
            fcn = "toyToolOne";
            archive = "jsonEncMultiOut";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, wrapper="None", encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            a = 3; b = uint64(5);
            [eX, eY, eZ] = toyToolOne(a, b);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aX, aY, aZ] = prodserver.mcp.call(endpoint, fcn, a, b);

                test.verifyEqual(aX, double(eX), ...
                    "[" + p + "]", AbsTol=1e-10);
                test.verifyEqual(aY, double(eY), ...
                    "[" + p + "]", AbsTol=1e-10);
                test.verifyEqual(aZ, double(eZ), ...
                    "[" + p + "]", AbsTol=1e-10);
            end
        end

        function scalarFourInputs(test)
            fcn = "toyScalarFour";
            archive = "jsonEncFourIn";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            a = 1103515245; c = 12345; m = 2^31; x0 = 7;
            expected = toyScalarFour(a, c, m, x0);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                actual = prodserver.mcp.call(endpoint, fcn, a, c, m, x0);
                test.verifyEqual(actual, expected, "[" + p + "]");
            end
        end

        function stringOutput(test)
            fcn = "toyScalarTwo";
            archive = "jsonEncString";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            s = "hello world"; n = 3;

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                % toyScalarTwo uses randi internally so results are
                % non-deterministic. Verify structural properties instead.
                [aCS, aD] = prodserver.mcp.call(endpoint, fcn, s, n);

                test.verifyTrue(ischar(aCS) || isstring(aCS), ...
                    "type [" + p + "]");
                test.verifyEqual(strlength(string(aCS)), strlength(s), ...
                    "length [" + p + "]");
                test.verifyClass(aD, "double", "[" + p + "]");
                test.verifyGreaterThanOrEqual(aD, 0, "[" + p + "]");
            end
        end

        function optionalPositional(test)
            fcn = "toyScalarOptions";
            archive = "jsonEncOptPos";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            args = {1999, 1001, 100000, "Polaris", "Zeta"};
            expectedAll = feval(fcn, args{:});
            expectedReq = feval(fcn, 1999);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                % Call with all arguments
                actual = prodserver.mcp.call(endpoint, fcn, args{:});
                test.verifyEqual(string(actual), expectedAll, ...
                    "All args [" + p + "]");

                % Call with only required argument
                actual = prodserver.mcp.call(endpoint, fcn, 1999);
                test.verifyEqual(string(actual), expectedReq, ...
                    "Required only [" + p + "]");
            end
        end

        function optionalNVP(test)
            fcn = "toyScalarNVOptions";
            archive = "jsonEncOptNVP";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            year = 2020;
            expectedNVP = feval(fcn, year, mpg=50, make="Tesla");
            expectedReq = feval(fcn, year);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                % Call with NVP arguments
                actual = prodserver.mcp.call(endpoint, fcn, year, ...
                    'mpg', 50, 'make', "Tesla");
                test.verifyEqual(string(actual), expectedNVP, ...
                    "With NVP [" + p + "]");

                % Required only
                actual = prodserver.mcp.call(endpoint, fcn, year);
                test.verifyEqual(string(actual), expectedReq, ...
                    "Required only [" + p + "]");
            end
        end

        function multiToolArchive(test)
            fcns = ["toyScalarOne", "toyScalarFour"];
            archive = "jsonEncMultiTool";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            ctf = prodserver.mcp.build(fcns, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            x = 99;
            expected1 = toyScalarOne(x);

            a = 7; c = 3; m = 100; x0 = 42;
            expected4 = toyScalarFour(a, c, m, x0);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcns(1), "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcns(1) + " not found [" + p + "]");

                % Call first tool
                actual = prodserver.mcp.call(endpoint, fcns(1), x);
                test.verifyEqual(actual, expected1, ...
                    "toyScalarOne [" + p + "]");

                % Call second tool
                actual = prodserver.mcp.call(endpoint, fcns(2), a, c, m, x0);
                test.verifyEqual(actual, expected4, ...
                    "toyScalarFour [" + p + "]");
            end
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
            tools = prodserver.mcp.list(endpoint, "Tool");
            names = cellfun(@(t)string(t.name), tools);
            t = tools{strcmp(names, fcn)};

            test.verifyFalse(contains(string(t.description), ...
                MCPConstants.WireEncodingResourceURI), ...
                "JSON tool should not reference wire encoding resource");
        end

        function schemaVectorJSON(test)
            % build warns if any input or output has no assigned type. But
            % that's not what we're testing here, so turn off that warning.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));

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

            v = [10, 20, 30, 40, 50];
            [eMag, eNorm, eCount] = schemaVectorNoBlock(v);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aMag, aNorm, aCount] = prodserver.mcp.call( ...
                    endpoint, fcn, v);

                test.verifyEqual(aMag, eMag, ...
                    "[" + p + "]", AbsTol=1e-12);
                test.verifyEqual(aCount, eCount, "[" + p + "]");
                % JSON loses orientation — compare values only
                test.verifyEqual(sort(aNorm(:)), sort(eNorm(:)), ...
                    "[" + p + "]", AbsTol=1e-12);
            end
        end

        function schemaDurationJSON(test)
            % build warns if any input or output has no assigned type. But
            % that's not what we're testing here, so turn off that warning.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));

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

            h = 2; m = 15; s = 30;
            [~, eTotalSec] = schemaDurationNoBlock(h, m, s);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [~, aTotalSec] = prodserver.mcp.call( ...
                    endpoint, fcn, h, m, s);

                test.verifyEqual(double(aTotalSec), double(eTotalSec), ...
                    "[" + p + "]", AbsTol=1e-10);
            end
        end

        function schemaDatetimeJSON(test)
            % build warns if any input or output has no assigned type. But
            % that's not what we're testing here, so turn off that warning.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));

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

            year = 2026; month = 8; day = 18;
            [~, eDow, eSerial] = schemaDatetimeNoBlock(year, month, day);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [~, aDow, aSerial] = prodserver.mcp.call(...
                    endpoint, fcn, year, month, day);

                % Day-of-week is a string — should come back as a char
                % because jsonencode is not Invertible.
                test.verifyEqual(aDow, char(eDow), "[" + p + "]");
                % Serial date number is numeric — should round-trip
                test.verifyEqual(double(aSerial), double(eSerial), ...
                    "[" + p + "]", AbsTol=1e-10);
            end
        end

        function externalArrayJSON(test)
        % Build and call a tool with externalized args under JSON encoding.
        % Externalized variables are always passed as file:// URIs.

            import prodserver.mcp.io.MarshallURI

            fcn = "allIndirect";
            archive = "jsonEncExternal";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireParamTools());

            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            a = 10; b = 20; c = 30; d = 40;
            [eX, eY, eZ] = allIndirect(a, b, c, d);

            m = MarshallURI();
            urlFolder = replace(test.tempFolder, filesep, "/");
            aFile = "file://" + urlFolder + "/a.mat";
            bFile = "file://" + urlFolder + "/b.mat";
            cFile = "file://" + urlFolder + "/c.mat";
            dFile = "file://" + urlFolder + "/d.mat";
            xFile = "file://" + urlFolder + "/x.mat";
            yFile = "file://" + urlFolder + "/y.mat";
            zFile = "file://" + urlFolder + "/z.mat";

            serialize(m, aFile, {a});
            serialize(m, bFile, {b});
            serialize(m, cFile, {c});
            serialize(m, dFile, {d});

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                prodserver.mcp.call(endpoint, fcn, ...
                    aFile, bFile, cFile, dFile, ...
                    xURL=xFile, yURL=yFile, zURL=zFile);

                aX = deserialize(m, xFile); aX = aX{1};
                aY = deserialize(m, yFile); aY = aY{1};
                aZ = deserialize(m, zFile); aZ = aZ{1};

                test.verifyEqual(double(aX), double(eX), ...
                    "X [" + p + "]", AbsTol=1e-10);
                test.verifyEqual(double(aY), double(eY), ...
                    "Y [" + p + "]", AbsTol=1e-10);
                test.verifyEqual(double(aZ), double(eZ), ...
                    "Z [" + p + "]", AbsTol=1e-10);
            end
        end

    end
end
