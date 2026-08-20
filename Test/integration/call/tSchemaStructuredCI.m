classdef tSchemaStructuredCI < MCPCaller
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
                folder=test.tempFolder, archive=archive, wrapper="None", ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            realPart = [3, 0]; imagPart = [4, 1];
            [eZ, eMag, ePhase] = schemaComplexNoBlock(realPart, imagPart);
            [aZ, aMag, aPhase] = prodserver.mcp.call(...
                endpoint, fcn, realPart, imagPart);

            test.verifyEqual(aZ, eZ, AbsTol=1e-12);
            test.verifyEqual(aMag, eMag, AbsTol=1e-12);
            test.verifyEqual(aPhase, ePhase, AbsTol=1e-12);
        end

        function datetimeRoundTrip(test)
            fcn = "schemaDatetimeNoBlock";
            archive = "schemaStructDT";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callDatetime(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, wrapper="None", ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            year = 2026; month = 6; day = 20;
            [eDt, eDow, eSerial] = schemaDatetimeNoBlock(year, month, day);
            [aDt, aDow, aSerial] = prodserver.mcp.call(...
                endpoint, fcn, year, month, day);

            test.verifyEqual(aDt, eDt);
            test.verifyEqual(aDow, eDow);
            test.verifyEqual(aSerial, eSerial);
        end

        function durationRoundTrip(test)
            fcn = "schemaDurationNoBlock";
            archive = "schemaStructDur";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callDuration(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, wrapper="None", ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            h = 1; m = 30; s = 45;
            [eDur, eTotalSec] = schemaDurationNoBlock(h, m, s);
            [aDur, aTotalSec] = prodserver.mcp.call(...
                endpoint, fcn, h, m, s);

            test.verifyEqual(aDur, eDur);
            test.verifyEqual(aTotalSec, eTotalSec);
        end

        function tableRoundTrip(test)
            fcn = "schemaTableNoBlock";
            archive = "schemaStructTbl";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callTable(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, wrapper="None", ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            names = ["Alice", "Bob"]; ages = [30, 25]; city = "NYC";
            [eT, eNrows] = schemaTableNoBlock(names, ages, city);
            [aT, aNrows] = prodserver.mcp.call(...
                endpoint, fcn, names, ages, city);

            test.verifyEqual(aT, eT);
            test.verifyEqual(aNrows, eNrows);
        end

        function timetableRoundTrip(test)
            fcn = "schemaTimetableNoBlock";
            archive = "schemaStructTT";
            test.applyFixture(prodserver.mcp.test.mixin.RemoveArchive(...
                test.server, archive));

            defs = prodserver.mcp.schema(fcn, ...
                @() callTimetable(), encoding="Invertible");
            ctf = prodserver.mcp.build(fcn, definition=defs, ...
                folder=test.tempFolder, archive=archive, wrapper="None", ...
                encoding="Invertible");
            endpoint = prodserver.mcp.deploy(ctf, test.server);

            tf = prodserver.mcp.exist(endpoint, fcn, "Tool", ...
                delay=10, retry=5);
            test.verifyTrue(tf, fcn + " not found at " + endpoint);

            values = [10, 20, 30]; startHour = 9; intervalMin = 15;
            [eTT, eNrows, eSpan] = schemaTimetableNoBlock(...
                values, startHour, intervalMin);
            [aTT, aNrows, aSpan] = prodserver.mcp.call(...
                endpoint, fcn, values, startHour, intervalMin);

            test.verifyEqual(aTT, eTT);
            test.verifyEqual(aNrows, eNrows);
            test.verifyEqual(aSpan, eSpan);
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
