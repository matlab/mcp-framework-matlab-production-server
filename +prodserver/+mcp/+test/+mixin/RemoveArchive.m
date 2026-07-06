classdef RemoveArchive < matlab.unittest.fixtures.Fixture
% A fixture for pre- and post-test removal of generated archives.

% Copyright 2026, The MathWorks, Inc.

    properties
        archiveName
        server
    end

    methods
        function fix = RemoveArchive(server, archiveName)
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
            tf = (fx1.archiveName == fx2.archiveName) && ...
                (fx1.server == fx2.server);
        end

    end
end
