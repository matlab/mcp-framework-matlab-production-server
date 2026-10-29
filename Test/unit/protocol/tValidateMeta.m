classdef tValidateMeta < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.validateMeta.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        C
        MetaField
    end

    methods (TestMethodSetup)
        function loadConstants(test)
            test.C = prodserver.mcp.protocol.v20260728.Constants;
            test.MetaField = prodserver.mcp.MCPConstants.MetaField;
        end
    end

    methods (Test)

        function tMissingParamsThrows(test)
            jrpc = struct('method', 'tools/list');
            test.verifyError( ...
                @() prodserver.mcp.protocol.v20260728.validateMeta(jrpc), ...
                'prodserver:mcp:MissingMeta');
        end

        function tMissingMetaFieldThrows(test)
            jrpc = struct('method', 'tools/list', 'params', struct());
            test.verifyError( ...
                @() prodserver.mcp.protocol.v20260728.validateMeta(jrpc), ...
                'prodserver:mcp:MissingMeta');
        end

        function tMissingProtocolVersionThrows(test)
            meta = struct(test.C.MetaCapabilities_Field, struct());
            jrpc = struct('method', 'tools/list', ...
                'params', struct(test.MetaField, meta));
            test.verifyError( ...
                @() prodserver.mcp.protocol.v20260728.validateMeta(jrpc), ...
                'prodserver:mcp:MissingProtocolVersion');
        end

        function tMissingCapabilitiesThrows(test)
            meta = struct(test.C.MetaProtocolVersion_Field, test.C.Version);
            jrpc = struct('method', 'tools/list', ...
                'params', struct(test.MetaField, meta));
            test.verifyError( ...
                @() prodserver.mcp.protocol.v20260728.validateMeta(jrpc), ...
                'prodserver:mcp:MissingCapabilities');
        end

        function tValidMetaReturnsFields(test)
            meta = struct( ...
                test.C.MetaProtocolVersion_Field, test.C.Version, ...
                test.C.MetaCapabilities_Field, struct());
            jrpc = struct('method', 'tools/list', ...
                'params', struct(test.MetaField, meta));
            [version, caps, clientInfo] = ...
                prodserver.mcp.protocol.v20260728.validateMeta(jrpc);
            test.verifyEqual(version, test.C.Version);
            test.verifyTrue(isstruct(caps));
            test.verifyEmpty(clientInfo);
        end

        function tOptionalClientInfoReturned(test)
            info = struct('name', "TestClient", 'version', "1.0");
            meta = struct( ...
                test.C.MetaProtocolVersion_Field, test.C.Version, ...
                test.C.MetaCapabilities_Field, struct(), ...
                test.C.MetaClientInfo_Field, info);
            jrpc = struct('method', 'tools/list', ...
                'params', struct(test.MetaField, meta));
            [~, ~, clientInfo] = ...
                prodserver.mcp.protocol.v20260728.validateMeta(jrpc);
            test.verifyEqual(string(clientInfo.name), "TestClient");
        end

    end

end
