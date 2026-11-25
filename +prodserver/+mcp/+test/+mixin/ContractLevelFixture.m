classdef ContractLevelFixture < matlab.unittest.fixtures.Fixture
% A fixture that sets the contract checking level for a test, and restores
% the previous level afterwards.
%
%   test.applyFixture(prodserver.mcp.test.mixin.ContractLevelFixture( ...
%       prodserver.mcp.contract.Level.None));

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = immutable)
        Level (1,1) prodserver.mcp.contract.Level = "Memory"
    end

    properties (Access = private)
        Previous
    end

    methods
        function fix = ContractLevelFixture(level)
            arguments
                level (1,1) prodserver.mcp.contract.Level
            end
            fix.Level = level;
            fix.SetupDescription = "Set the contract level to " + string(level) + ".";
            fix.TeardownDescription = "Restore the contract level.";
        end

        function setup(fix)
            fix.Previous = prodserver.mcp.contract.internal.configuredLevel();
            prodserver.mcp.contract.internal.configuredLevel(fix.Level);
        end

        function teardown(fix)
            prodserver.mcp.contract.internal.configuredLevel(fix.Previous);
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fx1, fx2)
            tf = fx1.Level == fx2.Level;
        end
    end
end
