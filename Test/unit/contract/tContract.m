classdef tContract < matlab.unittest.TestCase
% prodserver.mcp.contract: the levels, the enforce guard and ensure.
%
% The level is read once per process and cached. Each test that reads the
% environment forgets the cached level first, and restores it afterwards.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function defaultIsMemoryOutsideMPS(test)
            freshRead(test, "", "");
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), ...
                prodserver.mcp.contract.Level.Memory);
        end

        function defaultIsNoneOnAnMPSWorker(test)
            freshRead(test, "", "C:\mps\instance\endpoint");
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), ...
                prodserver.mcp.contract.Level.None);
        end

        function environmentOverridesEitherDefault(test)
            freshRead(test, "storage", "C:\mps\instance\endpoint");
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), ...
                prodserver.mcp.contract.Level.Storage);
            freshRead(test, " None ", "");
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), ...
                prodserver.mcp.contract.Level.None);
        end

        function unknownValueIsLoggedAndUsesTheDefault(test)
            freshRead(test, "Everything", "");
            captured = test.applyFixture(prodserver.mcp.test.mixin.LogCapture());
            level = test.verifyWarningFree( ...
                @() prodserver.mcp.contract.internal.configuredLevel());
            test.verifyEqual(level, prodserver.mcp.contract.Level.Memory);
            test.verifyNumElements(captured.Lines, 1);
            test.verifyEqual(captured.Streams, 2, "a warning goes to stderr");
            test.verifySubstring(captured.Lines(1), "[mcp:warning] prodserver:mcp:ContractLevelUnknown");
            test.verifySubstring(captured.Lines(1), "`Everything`");
            % Read once: the second call logs nothing more.
            prodserver.mcp.contract.internal.configuredLevel();
            test.verifyNumElements(captured.Lines, 1);
        end

        function levelIsReadOncePerProcess(test)
            freshRead(test, "Storage", "");
            prodserver.mcp.contract.internal.configuredLevel();
            setenv("MW_MPS_MCP_CONTRACTS", "None");
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), ...
                prodserver.mcp.contract.Level.Storage);
        end

        function enforceIncludesEveryCheaperLevel(test)
            import prodserver.mcp.contract.Level
            import prodserver.mcp.contract.enforce
            test.applyFixture(prodserver.mcp.test.mixin.ContractLevelFixture(Level.Memory));
            test.verifyTrue(enforce(Level.None));
            test.verifyTrue(enforce(Level.Memory));
            test.verifyFalse(enforce(Level.Storage));
        end

        function enforceAtNoneRunsNoGuardedCheck(test)
            import prodserver.mcp.contract.Level
            import prodserver.mcp.contract.enforce
            test.applyFixture(prodserver.mcp.test.mixin.ContractLevelFixture(Level.None));
            test.verifyFalse(enforce(Level.Memory));
            test.verifyFalse(enforce(Level.Storage));
        end

        function enforceAcceptsALevelName(test)
            test.applyFixture(prodserver.mcp.test.mixin.ContractLevelFixture("Storage"));
            test.verifyTrue(prodserver.mcp.contract.enforce("Storage"));
        end

        function fixtureRestoresThePreviousLevel(test)
            import prodserver.mcp.contract.Level
            before = prodserver.mcp.contract.internal.configuredLevel();
            other = Level.Storage;
            if before == other, other = Level.None; end
            fix = prodserver.mcp.test.mixin.ContractLevelFixture(other);
            fix.setup();
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), other);
            fix.teardown();
            test.verifyEqual(prodserver.mcp.contract.internal.configuredLevel(), before);
        end

        function ensureReturnsWhenTheConditionHolds(test)
            test.verifyWarningFree(@() prodserver.mcp.contract.ensure(true, "always"));
        end

        function ensureRaisesAViolationNamingTheClause(test)
            try
                prodserver.mcp.contract.ensure(1 > 2, "publish: State == ""published""");
                test.verifyFail("ensure returned on a false condition");
            catch me
                test.verifyEqual(string(me.identifier), ...
                    "prodserver:mcp:internal:ContractViolation");
                test.verifySubstring(string(me.message), "publish: State == ""published""");
                % Reported at the caller, not inside ensure.
                test.verifyNotEqual(string(me.stack(1).name), "ensure");
            end
        end

        function ensureRequiresALogicalScalarAndAClause(test)
            test.verifyError(@() prodserver.mcp.contract.ensure([true true], "x"), ...
                "MATLAB:validation:IncompatibleSize");
            test.verifyError(@() prodserver.mcp.contract.ensure(true, ""), ...
                "MATLAB:validators:mustBeNonzeroLengthText");
        end
    end

    methods (Access = private)
        function freshRead(test, contracts, endpointRoot)
        % Forget the cached level, and set the two variables it is read from.
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            previous = prodserver.mcp.contract.internal.configuredLevel();
            test.addTeardown(@() prodserver.mcp.contract.internal.configuredLevel(previous));
            test.applyFixture(EnvironmentVariableFixture("MW_MPS_MCP_CONTRACTS", contracts));
            test.applyFixture(EnvironmentVariableFixture("MPS_ENDPOINT_ROOT", endpointRoot));
            prodserver.mcp.contract.internal.configuredLevel([]);
        end
    end
end

