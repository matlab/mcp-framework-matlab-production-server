classdef tDefinitionLoad < prodserver.mcp.test.base.MCPHandlerBase
% A definition file that cannot be loaded (D37). toolServices must name the
% failure -- a class clash between archives, which needs a multi-MCOS
% restart, or an unreadable file -- keep load's own error as the cause, not
% cache the failure, and still reach the client as -32603/500.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        InternalError = -32603;
        Tool = "toyScalarTwo";
    end

    properties (Access = private)
        goodBytes
    end

    methods (TestClassSetup)
        function prepareTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            defineTools(test, test.Tool, test.Tool, ...
                encoding=prodserver.mcp.WireEncoding.JSON);
            test.goodBytes = readBytes(test.definitionFile);
        end
    end

    methods (TestMethodSetup)
        function freshCache(test)
            % Every test starts from the intact file and an empty cache, and
            % leaves both that way, whatever it did in between.
            writeBytes(test.definitionFile, test.goodBytes);
            prodserver.mcp.handler.toolServices(action="clear");
            test.addTeardown(@() writeBytes(test.definitionFile, test.goodBytes));
            test.addTeardown(@() ...
                prodserver.mcp.handler.toolServices(action="clear"));
        end
    end

    methods (Test)

        function corruptFileIsDefinitionLoadFailed(test)
            writeBytes(test.definitionFile, uint8('this is not a MAT file'));
            err = test.loadError();
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:DefinitionLoadFailed");
            test.verifyNotEmpty(err.cause, ...
                "load's own error must be kept for the server log");
        end

        function classClashIsNeedMultiMCOSMode(test)
            % A real class clash needs two archives in one worker, and load
            % downgrades a failing loadobj to a warning, so neither can be
            % provoked here. Shadow load instead, for the definition file
            % only, with an identifier from the class-system catalog.
            test.shadowLoad("MATLAB:class:InvalidEnum");
            err = test.loadError();
            test.verifyEqual(string(err.identifier), ...
                "prodserver:mcp:NeedMultiMCOSMode");
            test.verifyTrue(contains(err.message, ...
                prodserver.mcp.internal.Constants.MultiMCOSEnvVar), err.message);
            test.assertNotEmpty(err.cause);
            test.verifyEqual(string(err.cause{1}.identifier), ...
                "MATLAB:class:InvalidEnum");
        end

        function failureIsNotCached(test)
            writeBytes(test.definitionFile, uint8('this is not a MAT file'));
            test.loadError();

            % Repaired file, no explicit clear: the next request must load
            % it rather than replay the failure or serve an empty cache.
            writeBytes(test.definitionFile, test.goodBytes);
            svc = prodserver.mcp.handler.toolServices;
            test.verifyTrue(isfield(svc, ...
                prodserver.mcp.MCPConstants.DefinitionVariable));
        end

        function loadFailureIs500(test)
            writeBytes(test.definitionFile, uint8('this is not a MAT file'));
            reqT = createRequest(test, test.Tool, test.server, ...
                s="hello world", n=2);
            response = test.handle(reqT);
            body = native2unicode(response.Body, "UTF-8");
            test.verifyEqual(response.HttpCode, 500, body);
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.assertTrue(prodserver.mcp.internal.hasField(decoded, ...
                'error.code'), body);
            test.verifyEqual(decoded.error.code, test.InternalError);
        end

    end

    methods (Access = private)

        function err = loadError(test)
            err = MException.empty;
            try
                prodserver.mcp.handler.toolServices;
            catch err
            end
            test.assertNotEmpty(err, "Expected toolServices to fail");
        end

        function shadowLoad(test, identifier)
        % Put a load.m ahead of the built-in that fails for the definition
        % file and defers to the built-in for everything else.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.SuppressedWarningsFixture

            folder = test.applyFixture(TemporaryFolderFixture).Folder;
            src = [
                "function varargout = load(varargin)"
                "    if nargin > 0 && endsWith(string(varargin{1}), """ + ...
                    prodserver.mcp.MCPConstants.DefinitionFile + """)"
                "        error(""" + identifier + """, ""synthetic class clash"");"
                "    end"
                "    [varargout{1:nargout}] = builtin(""load"", varargin{:});"
                "end"
                ];
            writelines(src, fullfile(folder, "load.m"));
            test.applyFixture(SuppressedWarningsFixture( ...
                "MATLAB:dispatcher:nameConflict"));
            test.applyFixture(PathFixture(folder));
        end

    end
end

function b = readBytes(file)
    fid = fopen(file, "r");
    c = onCleanup(@() fclose(fid));
    b = fread(fid, Inf, "*uint8");
end

function writeBytes(file, b)
    fid = fopen(file, "w");
    c = onCleanup(@() fclose(fid));
    fwrite(fid, b, "uint8");
end
