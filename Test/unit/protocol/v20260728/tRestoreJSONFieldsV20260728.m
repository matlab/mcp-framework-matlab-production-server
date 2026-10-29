classdef tRestoreJSONFieldsV20260728 < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20260728.restoreJSONFields.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        C = prodserver.mcp.protocol.v20260728.Constants
    end

    methods (Test)

        function tReplacesAllMetaFields(test)
            C = test.C;
            pairs = {
                C.MetaProtocolVersion_Field, C.MetaProtocolVersion_JSON
                C.MetaCapabilities_Field,    C.MetaCapabilities_JSON
                C.MetaClientInfo_Field,      C.MetaClientInfo_JSON
                C.MetaLogLevel_Field,        C.MetaLogLevel_JSON
                C.MetaServerInfo_Field,      C.MetaServerInfo_JSON
                C.MetaSubscriptionId_Field,  C.MetaSubscriptionId_JSON
            };
            for i = 1:size(pairs, 1)
                json = sprintf('{"%s":"value"}', pairs{i,1});
                result = prodserver.mcp.protocol.v20260728.restoreJSONFields(json);
                test.verifyTrue(contains(result, pairs{i,2}), ...
                    "Should replace " + pairs{i,1});
                test.verifyFalse(contains(result, pairs{i,1}), ...
                    "Should remove " + pairs{i,1});
            end
        end

        function tReplacesMultipleFieldsInOneString(test)
            C = test.C;
            json = sprintf('{"_meta":{"%s":"2026-07-28","%s":{"name":"test"}}}', ...
                C.MetaProtocolVersion_Field, C.MetaServerInfo_Field);
            result = prodserver.mcp.protocol.v20260728.restoreJSONFields(json);
            test.verifyTrue(contains(result, C.MetaProtocolVersion_JSON));
            test.verifyTrue(contains(result, C.MetaServerInfo_JSON));
            test.verifyFalse(contains(result, C.MetaProtocolVersion_Field));
            test.verifyFalse(contains(result, C.MetaServerInfo_Field));
        end

        function tPreservesUnrelatedContent(test)
            json = '{"result":{"tools":[{"name":"myTool"}]}}';
            result = prodserver.mcp.protocol.v20260728.restoreJSONFields(json);
            test.verifyEqual(result, json);
        end

        function tEmptyStringReturnsEmpty(test)
            result = prodserver.mcp.protocol.v20260728.restoreJSONFields('');
            test.verifyEqual(result, '');
        end

        function tLeavesFieldNameInValue(test)
            % Only keys are renamed: the same text in a string value stays.
            C = test.C;
            json = sprintf('{"msg":"see %s for details"}', C.MetaServerInfo_Field);
            result = prodserver.mcp.protocol.v20260728.restoreJSONFields(json);
            test.verifyEqual(result, json);
        end

    end

end
