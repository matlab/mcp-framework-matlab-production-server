classdef tSchemaStructuredBI < matlab.unittest.TestCase & ...
        prodserver.mcp.test.mixin.MCPServer
% Test build and execution of MCP server using schema-generated definitions
% for functions that return structured MATLAB types (datetime, duration,
% table, timetable, complex).

% Copyright 2026 The MathWorks, Inc.

    properties
        tempFolder
        server
        fcns
    end

    methods(TestClassSetup)
        function buildServer(test)
        %buildServer Generate schemas and build the MCP server.

            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import prodserver.mcp.MCPConstants

            % Put the schema tools on the path
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());

            % Create a temporary folder for all the deployment artifacts
            tempDir = TemporaryFolderFixture(WithSuffix="schemaStructBI");
            test.applyFixture(tempDir);
            test.tempFolder = tempDir.Folder;

            % Put the temporary folder on the path so that the handler can
            % load the definition file.
            test.applyFixture(PathFixture(test.tempFolder));

            % Five structured-type tools
            test.fcns = ["schemaComplexNoBlock", "schemaDatetimeNoBlock", ...
                "schemaDurationNoBlock", "schemaTableNoBlock", ...
                "schemaTimetableNoBlock"];

            % Generate schema definitions via observation
            defs = prodserver.mcp.schema(test.fcns, ...
                @() exerciseStructuredTools());

            % Build the tools using schema-generated definitions
            test.server = "schemaStructuredBI";
            ctf = prodserver.mcp.build(test.fcns, definition=defs, ...
                folder=test.tempFolder, archive=test.server, ...
                wrapper=repmat("None", size(test.fcns)));

            test.verifyTrue(startsWith(ctf, test.tempFolder), ctf);
        end
    end

    methods (TestMethodSetup)
        function switchContext(~)
            % Clear tool definition cache.
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods(Test)

        function definitionFileExists(test)
            import prodserver.mcp.MCPConstants
            defFile = fullfile(test.tempFolder, MCPConstants.DefinitionFile);
            test.verifyEqual(exist(defFile, "file"), 2, defFile);
        end

        function toolCountCorrect(test)
            import prodserver.mcp.MCPConstants
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            % +1 for read_mcp_resource
            test.verifyEqual(numel(def.tools), numel(test.fcns)+1);
        end

        function toolNamesCorrect(test)
            import prodserver.mcp.MCPConstants
            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);
            names = cellfun(@(t)string(t.name), def.tools);
            for n = 1:numel(test.fcns)
                test.verifyTrue(ismember(test.fcns(n), names), ...
                    test.fcns(n) + " not in definition");
            end
        end

        function callComplex(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaComplexNoBlock";
            realPart = [3, 0]; imagPart = [4, 1];
            [eZ, eMag, ePhase] = schemaComplexNoBlock(realPart, imagPart);

            t = findDefinition(fcn, def);
            s = def.signatures;

            body = jsonToolCall(test, fcn, 2, t, s, realPart, imagPart);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.z, eZ, AbsTol=1e-12);
            test.verifyEqual(sc.mag, eMag, AbsTol=1e-12);
            test.verifyEqual(sc.phase, ePhase, AbsTol=1e-12);
        end

        function callDatetime(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaDatetimeNoBlock";
            year = 2026; month = 3; day = 15;
            [eDt, eDow, eSerial] = schemaDatetimeNoBlock(year, month, day);

            t = findDefinition(fcn, def);
            s = def.signatures;

            body = jsonToolCall(test, fcn, 2, t, s, year, month, day);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.dt, eDt);
            test.verifyEqual(string(sc.dow), eDow);
            test.verifyEqual(sc.serial, eSerial);
        end

        function callDuration(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaDurationNoBlock";
            h = 1; m = 30; s = 45;
            [eDur, eTotalSec] = schemaDurationNoBlock(h, m, s);

            t = findDefinition(fcn, def);
            sig = def.signatures;

            body = jsonToolCall(test, fcn, 2, t, sig, h, m, s);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.dur, eDur);
            test.verifyEqual(sc.totalSec, eTotalSec);
        end

        function callTable(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaTableNoBlock";
            names = ["Alice", "Bob"]; ages = [30, 25]; city = "NYC";
            [eT, eNrows] = schemaTableNoBlock(names, ages, city);

            t = findDefinition(fcn, def);
            s = def.signatures;

            body = jsonToolCall(test, fcn, 2, t, s, names, ages, city);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.T, eT);
            test.verifyEqual(sc.nrows, eNrows);
        end

        function callTimetable(test)
            import prodserver.mcp.MCPConstants

            def = load(fullfile(test.tempFolder, MCPConstants.DefinitionFile));
            def = def.(MCPConstants.DefinitionVariable);

            fcn = "schemaTimetableNoBlock";
            values = [10, 20, 30]; startHour = 9; intervalMin = 15;
            [eTT, eNrows, eSpan] = schemaTimetableNoBlock(...
                values, startHour, intervalMin);

            t = findDefinition(fcn, def);
            s = def.signatures;

            body = jsonToolCall(test, fcn, 2, t, s, ...
                values, startHour, intervalMin);
            req = mcpRequest(test, test.server, body=body);
            resp = handleRequest(test, req);

            test.verifyFalse(isfield(resp, 'error'), "Error field present");
            test.verifyTrue(isfield(resp, 'result'), "Result field missing");

            sc = resp.result.structuredContent;
            test.verifyEqual(sc.TT, eTT);
            test.verifyEqual(sc.nrows, eNrows);
            test.verifyEqual(sc.span, eSpan);
        end

    end
end

function exerciseStructuredTools()
    [~,~,~] = schemaComplexNoBlock([3,0], [4,1]);
    [~,~,~] = schemaDatetimeNoBlock(2026, 3, 15);
    [~,~]   = schemaDurationNoBlock(1, 30, 45);
    [~,~]   = schemaTableNoBlock(["Alice","Bob"], [30,25], "NYC");
    [~,~,~] = schemaTimetableNoBlock([10,20,30], 9, 15);
end

function t = findDefinition(tool, def)
    tName = cellfun(@(t)string(t.name), def.tools);
    k = strcmp(tool, tName);
    t = def.tools{k};
end
