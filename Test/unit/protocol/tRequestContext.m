classdef tRequestContext < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.RequestContext.

% Copyright 2026 The MathWorks, Inc.

    methods (Test)

        function tVersionOnly(test)
        % A context with only a version: no capabilities, no client info.
            ctx = prodserver.mcp.protocol.RequestContext("2025-06-18");
            test.verifyEqual(ctx.Version, "2025-06-18");
            test.verifyClass(ctx.Capabilities, "prodserver.mcp.protocol.ClientCapabilities");
            test.verifyFalse(supports(ctx.Capabilities, "io.modelcontextprotocol/ui"));
            test.verifyEqual(ctx.ClientInfo, []);
        end

        function tWithCapabilitiesAndClientInfo(test)
            import prodserver.mcp.protocol.ClientCapabilities
            caps = ClientCapabilities(jsondecode( ...
                '{"extensions":{"io.modelcontextprotocol/ui":{}}}'));
            info = struct("name", "test", "version", "1.0");
            ctx = prodserver.mcp.protocol.RequestContext("2026-07-28", ...
                Capabilities=caps, ClientInfo=info);
            test.verifyTrue(supports(ctx.Capabilities, "io.modelcontextprotocol/ui"));
            test.verifyEqual(ctx.ClientInfo, info);
        end

        function tVersionRequired(test)
            test.verifyError(@() prodserver.mcp.protocol.RequestContext(), ...
                "MATLAB:minrhs");
            test.verifyError(@() prodserver.mcp.protocol.RequestContext(""), ...
                "MATLAB:validators:mustBeNonzeroLengthText");
        end

    end
end
