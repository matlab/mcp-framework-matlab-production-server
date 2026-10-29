classdef tBase64 < matlab.unittest.TestCase
% prodserver.mcp.internal.base64encode and base64decode, and the rule that
% the framework uses nothing else.
%
% The two wrappers are the single place to swap in a faster Base64. That
% only works if no other file calls matlab.net.base64encode or
% base64decode directly, which onlyWrappersCallMatlabNet enforces.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        bytes = struct( ...
            "empty", uint8.empty(1,0), ...
            "one", uint8(255), ...
            "two", uint8([0 1]), ...
            "three", uint8([1 2 3]), ...
            "allValues", uint8(0:255))
    end

    methods (Test)

        function roundTrips(test, bytes)
            enc = prodserver.mcp.internal.base64encode(bytes);
            test.verifyEqual(prodserver.mcp.internal.base64decode(enc), bytes);
        end

        function matchesRFC4648(test)
            test.verifyEqual(string(prodserver.mcp.internal.base64encode( ...
                uint8('foobar'))), "Zm9vYmFy");
            test.verifyEqual(string(prodserver.mcp.internal.base64encode( ...
                uint8('fo'))), "Zm8=");
        end

        function columnInputEncodesLikeRow(test)
            b = uint8([10 20 30 40]);
            test.verifyEqual(prodserver.mcp.internal.base64encode(b'), ...
                prodserver.mcp.internal.base64encode(b));
        end

        function onlyWrappersCallMatlabNet(test)
            root = fullfile(prodserver.mcp.internal.packageFolder(), ...
                "+prodserver");
            files = dir(fullfile(root, "**", "*.m"));
            wrappers = ["base64encode.m", "base64decode.m"];
            offenders = string.empty;
            for f = files'
                path = fullfile(f.folder, f.name);
                if ismember(f.name, wrappers) && endsWith(f.folder, "+internal")
                    continue
                end
                if contains(fileread(path), "matlab.net.base64")
                    offenders(end+1) = string(path); %#ok<AGROW>
                end
            end
            test.verifyEmpty(offenders, "Call prodserver.mcp.internal." + ...
                "base64encode/base64decode instead of matlab.net: " + ...
                strjoin(offenders, ", "));
        end

    end
end
