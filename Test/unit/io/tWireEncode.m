classdef tWireEncode < matlab.unittest.TestCase
% Test round-trip invariance x == mcpWireDecode(mcpWireEncode(x))
% for all types supported by the MCP wire encoding.

    methods (Test)

        function tDouble(test)
            % Scalar — encoded as bare JSON primitives
            test.roundTrip(0);
            test.roundTrip(1);
            test.roundTrip(-1);
            test.roundTrip(pi);
            test.roundTrip(NaN);
            test.roundTrip(Inf);
            test.roundTrip(-Inf);
            % Arrays
            test.roundTrip([1 2 3]);                     % row vector
            test.roundTrip([1; 2; 3]);                   % column vector
            test.roundTrip(magic(4));                    % square matrix
            test.roundTrip(reshape(1:24, 2, 3, 4));      % 3-D array
            test.roundTrip(double.empty(0, 3));          % empty
            test.roundTrip([1 NaN Inf -Inf 0]);          % NaN / Inf sentinels
        end

        function tDoubleComplex(test)
            test.roundTrip(3 + 4i);
            test.roundTrip([1+2i, 3+4i; 5+6i, 7+8i]);
            test.roundTrip([1+2i, 3-4i; 5-6i, 7+8i]);
            test.roundTrip(complex(NaN, Inf));
        end

        function tIntegerTypes(test)
            for cls = ["int8","int16","int32","int64", ...
                       "uint8","uint16","uint32","uint64"]
                test.roundTrip(cast(42, cls));
                test.roundTrip(cast([1 2 3; 4 5 6], cls));
            end
        end

        function tSingle(test)
            test.roundTrip(single(3.14));
            test.roundTrip(single(NaN));
            test.roundTrip(single([1 2; 3 4]));
        end

        function tLogical(test)
            test.roundTrip(true);
            test.roundTrip(false);
            test.roundTrip([true false true; false true false]);
            test.roundTrip(logical.empty(0, 2));
        end

        function tChar(test)
            test.roundTrip('hello world');   % row vector — bare string
            test.roundTrip('x');             % scalar char
            test.roundTrip('');              % empty (1×0)
            test.roundTrip(['abc'; 'def']); % multi-row matrix
        end

        function tString(test)
            test.roundTrip("hello");
            test.roundTrip(["a" "b"; "c" "d"]);
            test.roundTrip(string(missing));                         % scalar missing
            test.roundTrip([missing "hello"; "world" missing]);      % mixed
        end

        function tStruct(test)
            % Scalar struct — encoded as plain JSON object
            test.roundTrip(struct('x', 1, 'y', 2));
            % Scalar struct with nested array field
            test.roundTrip(struct('name', 'Alice', 'scores', [95 87 91]));
            % 1×3 struct array
            test.roundTrip(struct('a', {1, 2, 3}));
            % 2×2 struct array
            test.roundTrip(struct('p', {1, 2; 3, 4}, 'q', {'a', 'b'; 'c', 'd'}));
        end

        function tCell(test)
            test.roundTrip({1, 'hello', true});
            test.roundTrip({[1 2 3], struct('x', 1)});
            test.roundTrip({'a'; 'b'; 'c'});         % column
            test.roundTrip({});                      % empty
            test.roundTrip({1, {2, {3}}});           % nested cells
        end

        function tDatetime(test)
            % Scalar — encoded as bare ISO 8601 string
            test.roundTrip(datetime(2024, 6, 15, 10, 30, 0));
            test.roundTrip(datetime(2024, 6, 15, 10, 30, 0, 'TimeZone', 'UTC'));
            test.roundTrip(NaT);
            % 1-D array with NaT
            test.roundTrip([datetime(2024,1,1), NaT, datetime(2024,12,31)]);
            % Array UTC — encoded with j.tz field
            test.roundTrip(datetime(2024, 1, 1, 'TimeZone', 'UTC') + hours(0:3));
            % 2-D array with IANA timezone — name preserved via j.tz
            test.roundTrip(datetime(2024, 1, 1, 'TimeZone', 'America/New_York') + ...
                days(reshape(0:5, 2, 3)));
        end

        function tDuration(test)
            % Scalar — encoded as {"type":"duration","seconds":N}
            test.roundTrip(seconds(30));
            test.roundTrip(hours(1.5));
            % Arrays
            test.roundTrip(seconds([1 2 3]));
            test.roundTrip(seconds([1 2; 3 4]));
        end

        function tCategorical(test)
            % Nominal
            test.roundTrip(categorical({'a', 'b', 'a', 'c'}));
            % 2-D
            test.roundTrip(categorical({'low','mid';'high','low'}, ...
                {'low','mid','high'}));
            % Ordinal
            test.roundTrip(categorical({'low', 'high', 'med'}, ...
                {'low', 'med', 'high'}, 'Ordinal', true));
            % With undefined element
            c = categorical({'a', 'b', 'c'}, {'a', 'b', 'c'});
            c(2) = missing;
            test.roundTrip(c);
        end

        function tTable(test)
            t = table([1;2;3], {'a';'b';'c'}, ...
                'VariableNames', {'num', 'str'});
            test.roundTrip(t);
            % With row names
            t.Properties.RowNames = {'r1', 'r2', 'r3'};
            test.roundTrip(t);
        end

        function tTimetable(test)
            times = datetime(2024, 1, 1) + hours(0:2)';
            tt = timetable(times, [1;2;3], {'a';'b';'c'}, ...
                'VariableNames', {'num', 'str'});
            test.roundTrip(tt);
        end

    end

    methods (Access = private)

        function roundTrip(test, x)
            % Verify that mcpWireDecode(mcpWireEncode(x)) reconstructs x exactly.
            % isequaln is used so that NaN == NaN and NaT == NaT.
            import prodserver.mcp.jsonrpc.mcpWireEncode
            import prodserver.mcp.jsonrpc.mcpWireDecode
            actual = mcpWireDecode(mcpWireEncode(x));
            test.verifyTrue(isequaln(actual, x), ...
                "Round-trip failed for " + class(x) + " " + mat2str(size(x)));
        end

    end

end
