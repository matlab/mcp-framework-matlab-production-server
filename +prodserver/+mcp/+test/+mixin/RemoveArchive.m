classdef RemoveArchive < matlab.unittest.fixtures.Fixture
% A fixture for pre- and post-test removal of generated archives.

% Copyright 2026 The MathWorks, Inc.

    properties
        archiveName
        server
    end

    methods
        function fix = RemoveArchive(server, archiveName)
            % The server's full address. Checked here, so that a test
            % without one gets this message once, not webwrite's protocol
            % error in both setup and teardown.
            if ~(isstring(server) || ischar(server)) || ...
                    ~isscalar(string(server)) || ...
                    ~startsWith(string(server), ["http://", "https://"], ...
                        IgnoreCase=true)
                if isempty(server), server = ""; end
                error("prodserver:mcp:test:NoServer", ...
                    "RemoveArchive needs the server's full address, such " + ...
                    "as http://localhost:9910, not '%s'. Is %s set?", ...
                    string(server), prodserver.mcp.MCPConstants.TestServerEnvVar);
            end
            fix.archiveName = archiveName;
            fix.server = server;
        end

        function setup(fix)
            gone = removeIfExists(fix);
        end

        function teardown(fix)
            gone = removeIfExists(fix);
        end

    end

    methods(Access=protected)
         
        function gone = removeIfExists(fix)
            % Send a DELETE to the archive. It should go away.

            options = weboptions('RequestMethod', 'delete');
            % No archives, nothing to remove: the loop below doesn't run.
            gone = true(1, 0);
            for n = numel(fix.archiveName):-1:1
                d = fix.server + "/api/archives?ctf="+fix.archiveName(n);
                try
                    goodbye = webwrite(d,options);
                catch me
                    % OK if archive is already gone or doesn't exist.
                    if ~contains(me.identifier,"HTTP403") && ...
                            ~contains(me.message,"no such archive")
                        rethrow(me);
                    end
                    % If it wasn't there, it's gone. :-)
                    goodbye.result = true;
                end
                gone(n) = isfield(goodbye,"result") && goodbye.result == true;
            end
        end

        function tf = isCompatible(fx1,fx2)
            % isequal: == on two lists of names, or two empty ones, isn't
            % a logical scalar.
            tf = isequal(fx1.archiveName, fx2.archiveName) && ...
                isequal(string(fx1.server), string(fx2.server));
        end

    end
end
