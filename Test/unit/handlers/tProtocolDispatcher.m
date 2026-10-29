classdef tProtocolDispatcher < matlab.unittest.TestCase
% Test prodserver.mcp.handler.ProtocolDispatcher routing and metadata.
%
% The dispatcher is the revision-independent half of request handling: the
% same method table serves every protocol revision, and the serving revision
% is passed down only so handlers need never re-derive it from the body. The
% routing tests are therefore parameterized by version -- not because routing
% is expected to differ, but because "it does not differ" is the claim worth
% holding onto as revisions are added.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        Dispatcher = prodserver.mcp.handler.ProtocolDispatcher.instance()
    end

    properties (TestParameter)
        % Filled in by registeredVersions below. Declared without a value: a
        % TestParameterDefinition method must match a parameterization
        % property declared in the same class.
        version
    end

    methods (Static, TestParameterDefinition)
        function version = registeredVersions()
            vs = prodserver.mcp.protocol.ProtocolRegistry.instance( ...
                ).supportedVersions();
            version = struct();
            for v = reshape(vs, 1, [])
                version.(matlab.lang.makeValidName("v" + v)) = v;
            end
        end
    end

    methods (Test)

        function tMethodNamesReturnsFive(test)
            names = test.Dispatcher.methodNames();
            test.verifyEqual(numel(names), 5);
            test.verifyTrue(ismember("tools/call", names));
            test.verifyTrue(ismember("tools/list", names));
            test.verifyTrue(ismember("resources/read", names));
            test.verifyTrue(ismember("resources/list", names));
            test.verifyTrue(ismember("resources/templates/list", names));
        end

        function tCapabilitiesHasToolsAndResources(test)
            caps = test.Dispatcher.capabilities();
            test.verifyTrue(isfield(caps, 'tools'));
            test.verifyTrue(isfield(caps, 'resources'));
            test.verifyEqual(numel(fieldnames(caps)), 2);
        end

        function tSingletonReturnsSameInstance(test)
            d1 = prodserver.mcp.handler.ProtocolDispatcher.instance();
            d2 = prodserver.mcp.handler.ProtocolDispatcher.instance();
            test.verifyTrue(d1 == d2);
        end

        function tTemplatesListReturnsTemplates(test, version)
            % resources/templates/list is explicitly handled (the resources
            % capability is advertised) and returns a well-formed, possibly
            % empty resourceTemplates array over HTTP 200 -- never 204. The
            % answer is the same for every revision.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, ...
                'method', 'resources/templates/list');
            [result, httpCode, ~, ~] = test.Dispatcher.dispatch(jrpc, version);
            test.verifyEqual(httpCode, 200);
            test.verifyTrue(isfield(result.result, 'resourceTemplates'));
        end

        function tUnknownMethodThrowsError(test, version)
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'bogus');
            test.verifyError(@() test.Dispatcher.dispatch(jrpc, version), ...
                'prodserver:mcp:MethodNotFound');
        end

        function tUnsupportedListThrowsMethodNotFound(test, version)
            % An unsupported */list (prompts/list, or an unknown variant) is
            % no longer answered with a blanket 204; it is Method not found.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, 'method', 'prompts/list');
            test.verifyError(@() test.Dispatcher.dispatch(jrpc, version), ...
                'prodserver:mcp:MethodNotFound');
            jrpc.method = 'widgets/list';
            test.verifyError(@() test.Dispatcher.dispatch(jrpc, version), ...
                'prodserver:mcp:MethodNotFound');
        end

        function tMethodNamesCaseInsensitive(test, version)
            % Dispatch lower-cases the method, so a known method matches
            % regardless of case.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, ...
                'method', 'RESOURCES/TEMPLATES/LIST');
            [~, httpCode, ~, ~] = test.Dispatcher.dispatch(jrpc, version);
            test.verifyEqual(httpCode, 200);
        end

        function tVersionIsRequired(test)
            % The serving revision is not defaulted. A caller that does not
            % know it has no business reaching the dispatcher, and a silent
            % default is how the per-revision metric would quietly acquire an
            % empty or wrong bucket again.
            jrpc = struct('jsonrpc', '2.0', 'id', 1, ...
                'method', 'resources/templates/list');
            test.verifyError(@() test.Dispatcher.dispatch(jrpc), ...
                'MATLAB:minrhs');
        end

        function tHandlerFilesReturnsFivePaths(test)
            files = test.Dispatcher.handlerFiles();
            test.verifyClass(files, 'string');
            test.verifyEqual(numel(files), 5);
            test.verifyTrue(all(strlength(files) > 0));
        end

    end

end
