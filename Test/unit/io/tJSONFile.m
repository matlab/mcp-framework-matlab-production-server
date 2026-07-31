classdef tJSONFile < matlab.unittest.TestCase
% Test prodserver.mcp.io.saveJSON and prodserver.mcp.io.loadJSON

% Copyright 2026 The MathWorks, Inc.

    properties
        tempDir
    end

    methods (TestClassSetup)
        function initFolder(test)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            test.tempDir = TemporaryFolderFixture(WithSuffix="jsontest");
            test.applyFixture(test.tempDir);
        end
    end

    methods (Test)

        % =================================================================
        % INVERTIBLE FORMAT — double scalars
        % =================================================================

        function invertibleDoubleScalar(test)
            test.invertibleRoundTrip(3.14);
            test.invertibleRoundTrip(0);
            test.invertibleRoundTrip(-1);
            test.invertibleRoundTrip(42);
        end

        function invertibleDoubleSpecial(test)
            test.invertibleRoundTrip(NaN);
            test.invertibleRoundTrip(Inf);
            test.invertibleRoundTrip(-Inf);
        end

        % =================================================================
        % INVERTIBLE FORMAT — double arrays
        % =================================================================

        function invertibleDoubleRowVector(test)
            test.invertibleRoundTrip([1 2 3]);
        end

        function invertibleDoubleColVector(test)
            test.invertibleRoundTrip([1; 2; 3]);
        end

        function invertibleDoubleMatrix(test)
            test.invertibleRoundTrip(magic(4));
        end

        function invertibleDouble3D(test)
            test.invertibleRoundTrip(reshape(1:24, 2, 3, 4));
        end

        function invertibleDoubleEmpty(test)
            test.invertibleRoundTrip(double.empty(0, 3));
        end

        function invertibleDoubleSpecialsInArray(test)
            test.invertibleRoundTrip([1 NaN Inf -Inf 0]);
        end

        % =================================================================
        % INVERTIBLE FORMAT — complex
        % =================================================================

        function invertibleComplexScalar(test)
            test.invertibleRoundTrip(3 + 4i);
            test.invertibleRoundTrip(complex(NaN, Inf));
        end

        function invertibleComplexArray(test)
            test.invertibleRoundTrip([1+2i, 3+4i; 5+6i, 7+8i]);
            test.invertibleRoundTrip([1+2i, 3-4i; 5-6i, 7+8i]);
        end

        % =================================================================
        % INVERTIBLE FORMAT — integer types
        % =================================================================

        function invertibleInt8(test)
            test.invertibleRoundTrip(int8([1 2 3; 4 5 6]));
        end

        function invertibleInt16(test)
            test.invertibleRoundTrip(int16([1 2 3; 4 5 6]));
        end

        function invertibleInt32(test)
            test.invertibleRoundTrip(int32([1 2 3; 4 5 6]));
        end

        function invertibleInt64(test)
            test.invertibleRoundTrip(int64([1 2 3; 4 5 6]));
        end

        function invertibleUint8(test)
            test.invertibleRoundTrip(uint8([1 2 3; 4 5 6]));
        end

        function invertibleUint16(test)
            test.invertibleRoundTrip(uint16([1 2 3; 4 5 6]));
        end

        function invertibleUint32(test)
            test.invertibleRoundTrip(uint32([1 2 3; 4 5 6]));
        end

        function invertibleUint64(test)
            test.invertibleRoundTrip(uint64([1 2 3; 4 5 6]));
        end

        function invertibleIntegerScalars(test)
            % Integer scalars are encoded as bare JSON numbers; the specific
            % integer class is not preserved through jsonencode/jsondecode.
            % Verify the value survives (as double).
            for cls = ["int8","int16","int32","int64", ...
                       "uint8","uint16","uint32","uint64"]
                file = fullfile(test.tempDir.Folder, "int_scalar.json");
                x = cast(42, cls);
                prodserver.mcp.io.saveJSON(file, x, format="Invertible");
                actual = prodserver.mcp.io.loadJSON(file);
                test.verifyEqual(actual, double(42), ...
                    "Integer scalar value not preserved for " + cls);
            end
        end

        % =================================================================
        % INVERTIBLE FORMAT — single
        % =================================================================

        function invertibleSingleScalar(test)
            % Single scalars are encoded as bare JSON numbers; the single
            % class is not preserved through jsonencode/jsondecode.
            file = fullfile(test.tempDir.Folder, "single_scalar.json");
            x = single(3.14);
            prodserver.mcp.io.saveJSON(file, x, format="Invertible");
            actual = prodserver.mcp.io.loadJSON(file);
            test.verifyEqual(actual, double(single(3.14)), ...
                "Single scalar value not preserved");
        end

        function invertibleSingleArray(test)
            test.invertibleRoundTrip(single([1 2; 3 4]));
            test.invertibleRoundTrip(single([NaN Inf; -Inf 0]));
        end

        % =================================================================
        % INVERTIBLE FORMAT — logical
        % =================================================================

        function invertibleLogicalScalar(test)
            test.invertibleRoundTrip(true);
            test.invertibleRoundTrip(false);
        end

        function invertibleLogicalArray(test)
            test.invertibleRoundTrip([true false true; false true false]);
        end

        function invertibleLogicalEmpty(test)
            test.invertibleRoundTrip(logical.empty(0, 2));
        end

        % =================================================================
        % INVERTIBLE FORMAT — char
        % =================================================================

        function invertibleCharRowVector(test)
            test.invertibleRoundTrip('hello world');
            test.invertibleRoundTrip('x');
        end

        function invertibleCharEmpty(test)
            test.invertibleRoundTrip('');
        end

        function invertibleCharMatrix(test)
            test.invertibleRoundTrip(['abc'; 'def']);
        end

        % =================================================================
        % INVERTIBLE FORMAT — string
        % =================================================================

        function invertibleStringScalar(test)
            test.invertibleRoundTrip("hello");
        end

        function invertibleStringArray(test)
            test.invertibleRoundTrip(["a" "b"; "c" "d"]);
        end

        function invertibleStringMissing(test)
            test.invertibleRoundTrip(string(missing));
            test.invertibleRoundTrip([missing "hello"; "world" missing]);
        end

        % =================================================================
        % INVERTIBLE FORMAT — struct
        % =================================================================

        function invertibleScalarStruct(test)
            test.invertibleRoundTrip(struct('x', 1, 'y', 2));
        end

        function invertibleScalarStructNestedArray(test)
            test.invertibleRoundTrip(struct('name', 'Alice', 'scores', [95 87 91]));
        end

        function invertibleStructArray(test)
            test.invertibleRoundTrip(struct('a', {1, 2, 3}));
            test.invertibleRoundTrip(struct('p', {1, 2; 3, 4}, 'q', {'a','b';'c','d'}));
        end

        % =================================================================
        % INVERTIBLE FORMAT — cell
        % =================================================================

        function invertibleCellMixed(test)
            test.invertibleRoundTrip({1, 'hello', true});
        end

        function invertibleCellNested(test)
            test.invertibleRoundTrip({[1 2 3], struct('x', 1)});
            test.invertibleRoundTrip({1, {2, {3}}});
        end

        function invertibleCellColumn(test)
            test.invertibleRoundTrip({'a'; 'b'; 'c'});
        end

        function invertibleCellEmpty(test)
            test.invertibleRoundTrip({});
        end

        % =================================================================
        % INVERTIBLE FORMAT — datetime
        % =================================================================

        function invertibleDatetimeScalarUnzoned(test)
            test.invertibleRoundTrip(datetime(2024, 6, 15, 10, 30, 0));
        end

        function invertibleDatetimeScalarUTC(test)
            test.invertibleRoundTrip(datetime(2024, 6, 15, 10, 30, 0, 'TimeZone', 'UTC'));
        end

        function invertibleDatetimeScalarNaT(test)
            test.invertibleRoundTrip(NaT);
        end

        function invertibleDatetimeArrayUnzoned(test)
            test.invertibleRoundTrip([datetime(2024,1,1), NaT, datetime(2024,12,31)]);
        end

        function invertibleDatetimeArrayUTC(test)
            test.invertibleRoundTrip(datetime(2024, 1, 1, 'TimeZone', 'UTC') + hours(0:3));
        end

        function invertibleDatetimeArrayIANA(test)
            test.invertibleRoundTrip(datetime(2024, 1, 1, 'TimeZone', 'America/New_York') + ...
                days(reshape(0:5, 2, 3)));
        end

        % =================================================================
        % INVERTIBLE FORMAT — duration
        % =================================================================

        function invertibleDurationScalar(test)
            test.invertibleRoundTrip(seconds(30));
            test.invertibleRoundTrip(hours(1.5));
        end

        function invertibleDurationArray(test)
            test.invertibleRoundTrip(seconds([1 2 3]));
            test.invertibleRoundTrip(seconds([1 2; 3 4]));
        end

        % =================================================================
        % INVERTIBLE FORMAT — categorical
        % =================================================================

        function invertibleCategoricalNominal(test)
            test.invertibleRoundTrip(categorical({'a', 'b', 'a', 'c'}));
        end

        function invertibleCategorical2D(test)
            test.invertibleRoundTrip(categorical({'low','mid';'high','low'}, ...
                {'low','mid','high'}));
        end

        function invertibleCategoricalOrdinal(test)
            test.invertibleRoundTrip(categorical({'low', 'high', 'med'}, ...
                {'low', 'med', 'high'}, 'Ordinal', true));
        end

        function invertibleCategoricalUndefined(test)
            c = categorical({'a', 'b', 'c'}, {'a', 'b', 'c'});
            c(2) = missing;
            test.invertibleRoundTrip(c);
        end

        % =================================================================
        % INVERTIBLE FORMAT — table
        % =================================================================

        function invertibleTable(test)
            t = table([1;2;3], {'a';'b';'c'}, ...
                'VariableNames', {'num', 'str'});
            test.invertibleRoundTrip(t);
        end

        function invertibleTableWithRowNames(test)
            t = table([1;2;3], {'a';'b';'c'}, ...
                'VariableNames', {'num', 'str'});
            t.Properties.RowNames = {'r1', 'r2', 'r3'};
            test.invertibleRoundTrip(t);
        end

        % =================================================================
        % INVERTIBLE FORMAT — timetable
        % =================================================================

        function invertibleTimetable(test)
            times = datetime(2024, 1, 1) + hours(0:2)';
            tt = timetable(times, [1;2;3], {'a';'b';'c'}, ...
                'VariableNames', {'num', 'str'});
            test.invertibleRoundTrip(tt);
        end

        % =================================================================
        % JSON FORMAT — round-trip tests (subset that plain JSON handles)
        % =================================================================

        function jsonDoubleScalar(test)
            test.jsonRoundTrip(3.14);
            test.jsonRoundTrip(0);
            test.jsonRoundTrip(42);
        end

        function jsonDoubleArray(test)
            % jsondecode always returns column vectors for 1-D JSON arrays,
            % and preserves shape for 2-D. Test accordingly.
            test.jsonRoundTrip([1; 2; 3]);
            test.jsonRoundTrip(magic(3));
        end

        function jsonLogicalScalar(test)
            test.jsonRoundTrip(true);
            test.jsonRoundTrip(false);
        end

        function jsonCharVector(test)
            test.jsonRoundTrip('hello');
        end

        function jsonScalarStruct(test)
            test.jsonRoundTrip(struct('x', 1, 'y', 2));
        end

        function jsonNestedStruct(test)
            s = struct('name', 'test', 'value', struct('a', 1, 'b', 2));
            test.jsonRoundTrip(s);
        end

        % =================================================================
        % NEGATIVE TESTS
        % =================================================================

        function loadNonExistentFile(test)
            bogusFile = fullfile(test.tempDir.Folder, "does_not_exist.json");
            test.verifyError(@() prodserver.mcp.io.loadJSON(bogusFile), ...
                'MATLAB:FileIO:InvalidFid');
        end

        function loadNonJSONContent(test)
            badFile = fullfile(test.tempDir.Folder, "notjson.json");
            writelines("this is not valid JSON { [ }", badFile);
            test.verifyError(@() prodserver.mcp.io.loadJSON(badFile), ...
                'MATLAB:json:ExpectedLiteral');
        end

        function saveInvalidFormat(test)
            outFile = fullfile(test.tempDir.Folder, "badformat.json");
            test.verifyError( ...
                @() prodserver.mcp.io.saveJSON(outFile, 42, format="bogus"), ...
                'MATLAB:validation:UnableToConvert');
        end

    end

    methods (Access = private)

        function invertibleRoundTrip(test, x)
            file = fullfile(test.tempDir.Folder, "invertible_test.json");
            prodserver.mcp.io.saveJSON(file, x, format="Invertible");
            actual = prodserver.mcp.io.loadJSON(file);
            test.verifyClass(actual, class(x), ...
                "Type not preserved for " + class(x) + " size " + mat2str(size(x)));
            test.verifyTrue(isequaln(actual, x), ...
                "Value not preserved for " + class(x) + " size " + mat2str(size(x)));
        end

        function jsonRoundTrip(test, x)
            file = fullfile(test.tempDir.Folder, "json_test.json");
            prodserver.mcp.io.saveJSON(file, x, format="JSON");
            actual = prodserver.mcp.io.loadJSON(file, format="JSON");
            test.verifyEqual(actual, x, ...
                "JSON round-trip failed for " + class(x) + " size " + mat2str(size(x)));
        end

    end

end
