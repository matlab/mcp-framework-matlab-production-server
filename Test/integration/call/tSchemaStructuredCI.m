classdef tSchemaStructuredCI < prodserver.mcp.test.base.MCPCaller
% Test deployment and invocation of MCP tools built from schema-generated
% definitions for functions that return structured MATLAB types (datetime,
% duration, table, timetable, complex).

% Copyright 2026 The MathWorks, Inc.

    methods (TestMethodSetup)
        function scratchSpace(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            tfolder = TemporaryFolderFixture;
            applyFixture(test, tfolder);
            setFolders(test, temp=tfolder.Folder);

            % Add schemaTools to path
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods (Test)

        function complexRoundTrip(test)
            fcn = "schemaComplexNoBlock";
            archive = "schemaStructCpx";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callComplex(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            realPart = [3, 0]; imagPart = [4, 1];
            [eZ, eMag, ePhase] = schemaComplexNoBlock(realPart, imagPart);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aZ, aMag, aPhase] = prodserver.mcp.call(...
                    endpoint, fcn, realPart, imagPart);

                test.verifyEqual(aZ, eZ, ...
                    "[" + p + "]", AbsTol=1e-12);
                test.verifyEqual(aMag, eMag, ...
                    "[" + p + "]", AbsTol=1e-12);
                test.verifyEqual(aPhase, ePhase, ...
                    "[" + p + "]", AbsTol=1e-12);
            end
        end

        function datetimeRoundTrip(test)
            fcn = "schemaDatetimeNoBlock";
            archive = "schemaStructDT";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callDatetime(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            year = 2026; month = 6; day = 20;
            [eDt, eDow, eSerial] = schemaDatetimeNoBlock(year, month, day);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aDt, aDow, aSerial] = prodserver.mcp.call(...
                    endpoint, fcn, year, month, day);

                test.verifyEqual(aDt, eDt, "[" + p + "]");
                test.verifyEqual(aDow, eDow, "[" + p + "]");
                test.verifyEqual(aSerial, eSerial, "[" + p + "]");
            end
        end

        function jsonTimesRoundTrip(test)
            % Plain JSON: datetimes go as ISO 8601 text and durations as
            % seconds, in both directions, and the client converts the
            % output back as the output schema says.
            fcn = "schemaWireTimes";
            archive = "schemaStructJSONTimes";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            % dn is (1,:), which would otherwise be passed by URL.
            ctf = prodserver.mcp.build(fcn, folder=test.tempFolder, ...
                archive=archive, encoding="JSON", wrapper="None");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            d1 = datetime(2026,3,4,5,6,7, TimeZone="UTC");
            dn = datetime(2026,1,1:2, TimeZone="UTC");
            d3 = hours([1 2 3]);
            expected = schemaWireTimes(d1, dn, d3);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, fcn + " not found [" + p + "]");

                actual = prodserver.mcp.call(endpoint, fcn, d1, dn, d3);
                test.verifyClass(actual, "datetime", "[" + p + "]");
                test.verifyEqual(actual, expected, "[" + p + "]");
            end
        end

        function durationRoundTrip(test)
            fcn = "schemaDurationNoBlock";
            archive = "schemaStructDur";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callDuration(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            h = 1; m = 30; s = 45;
            [eDur, eTotalSec] = schemaDurationNoBlock(h, m, s);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aDur, aTotalSec] = prodserver.mcp.call(...
                    endpoint, fcn, h, m, s);

                test.verifyEqual(aDur, eDur, "[" + p + "]");
                test.verifyEqual(aTotalSec, eTotalSec, "[" + p + "]");
            end
        end

        function tableRoundTrip(test)
            fcn = "schemaTableNoBlock";
            archive = "schemaStructTbl";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callTable(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            names = ["Alice", "Bob"]; ages = [30, 25]; city = "NYC";
            [eT, eNrows] = schemaTableNoBlock(names, ages, city);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aT, aNrows] = prodserver.mcp.call(...
                    endpoint, fcn, names, ages, city);

                test.verifyEqual(aT, eT, "[" + p + "]");
                test.verifyEqual(aNrows, eNrows, "[" + p + "]");
            end
        end

        function timetableRoundTrip(test)
            fcn = "schemaTimetableNoBlock";
            archive = "schemaStructTT";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callTimetable(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            values = [10, 20, 30]; startHour = 9; intervalMin = 15;
            [eTT, eNrows, eSpan] = schemaTimetableNoBlock(...
                values, startHour, intervalMin);

            for p = test.Protocols
                prodserver.mcp.client.Adapter.create(endpoint, action="clear");
                prodserver.mcp.client.Adapter.create(endpoint, protocol=p);

                tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                    delay=10, retry=5, protocol=p);
                test.verifyTrue(tf, ...
                    fcn + " not found [" + p + "]");

                [aTT, aNrows, aSpan] = prodserver.mcp.call(...
                    endpoint, fcn, values, startHour, intervalMin);

                test.verifyEqual(aTT, eTT, "[" + p + "]");
                test.verifyEqual(aNrows, eNrows, "[" + p + "]");
                test.verifyEqual(aSpan, eSpan, "[" + p + "]");
            end
        end

    end
end

function callComplex()
    [~,~,~] = schemaComplexNoBlock([3,0], [4,1]);
end

function callDatetime()
    [~,~,~] = schemaDatetimeNoBlock(2026, 3, 15);
end

function callDuration()
    [~,~] = schemaDurationNoBlock(1, 30, 45);
end

function callTable()
    [~,~] = schemaTableNoBlock(["Alice","Bob"], [30,25], "NYC");
end

function callTimetable()
    [~,~,~] = schemaTimetableNoBlock([10,20,30], 9, 15);
end
