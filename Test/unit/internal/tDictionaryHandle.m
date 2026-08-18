classdef tDictionaryHandle < matlab.unittest.TestCase
% Test prodserver.mcp.internal.DictionaryHandle (a handle wrapper around a
% dictionary, giving reference semantics and redefined paren/dot indexing).

% Copyright 2026 The MathWorks, Inc.

    methods

        function dh = doubleMap(~)
            dh = prodserver.mcp.internal.DictionaryHandle("string", "double");
        end

    end

    methods (Test)

        function tInsertAndCount(test)
            dh = test.doubleMap();
            insert(dh, "a", 1);
            insert(dh, "b", 2);
            test.verifyEqual(dh.Count, 2);
            test.verifyEqual(numEntries(dh), 2);
        end

        function tIsKey(test)
            dh = test.doubleMap();
            insert(dh, "a", 1);
            test.verifyTrue(isKey(dh, "a"));
            test.verifyFalse(isKey(dh, "z"));
        end

        function tKeysValuesEntriesTypes(test)
            dh = test.doubleMap();
            insert(dh, ["a", "b"], [1 2]);
            test.verifyEqual(sort(keys(dh)), ["a"; "b"]);
            test.verifyEqual(sort(values(dh)), [1; 2]);
            test.verifyEqual(height(entries(dh)), 2);
            [kt, vt] = types(dh);
            test.verifyEqual(kt, "string");
            test.verifyEqual(vt, "double");
        end

        function tParenReference(test)
            dh = test.doubleMap();
            insert(dh, "a", 7);
            test.verifyEqual(dh("a"), 7);
        end

        function tSize(test)
            dh = test.doubleMap();
            insert(dh, "a", 1);
            test.verifyEqual(size(dh), [1 1]);
        end

        function tHandleSemanticsAlias(test)
            % A copy is a reference — mutations are seen through both handles.
            dh = test.doubleMap();
            insert(dh, "a", 1);
            alias = dh;
            insert(alias, "b", 2);
            test.verifyEqual(dh.Count, 2);
            test.verifyTrue(isKey(dh, "b"));
        end

        function tRemove(test)
            dh = test.doubleMap();
            insert(dh, ["a", "b"], [1 2]);
            remove(dh, "a");
            test.verifyFalse(isKey(dh, "a"));
            test.verifyEqual(dh.Count, 1);
        end

        function tMerge(test)
            % merge folds donor dictionaries into the receiver (in place).
            a = test.doubleMap(); insert(a, "x", 1);
            b = test.doubleMap(); insert(b, ["y", "z"], [2 3]);
            merge(a, b);
            test.verifyEqual(a.Count, 3);
            test.verifyEqual(sort(keys(a)), ["x"; "y"; "z"]);
        end

        function tMergeEmptyDonorIsNoOp(test)
            a = test.doubleMap(); insert(a, "x", 1);
            merge(a, test.doubleMap());
            test.verifyEqual(a.Count, 1);
        end

        function tHeterogeneousCellDotAccess(test)
            % With a "cell" value type, dot get/set stores/unwraps arbitrary
            % values (here, structs) transparently.
            dh = prodserver.mcp.internal.DictionaryHandle("string", "cell");
            dh.item = struct("field", 42);
            test.verifyEqual(dh.item.field, 42);
            dh.item.field = 99;
            test.verifyEqual(dh.item.field, 99);
        end

        function tConcatenation(test)
            a = test.doubleMap(); insert(a, "p", 1);
            b = test.doubleMap(); insert(b, "q", 2);
            out = [a, b];
            test.verifyEqual(out.Count, 2);
        end

        function tParenDelete(test)
            dh = test.doubleMap();
            insert(dh, ["x", "y"], [1 2]);
            dh("x") = [];
            test.verifyFalse(isKey(dh, "x"));
        end

    end

end
