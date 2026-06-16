classdef File < prodserver.mcp.io.Scheme
%File Marshalling configuration for the file:// scheme.
%
%Minimal class required by scheme extension framework.

% Copyright 2024-2025 The MathWorks, Inc.

% Scheme-related errors belong in the storage category: storage.xml in the
% resources/data_pipeline/en folder.

    properties (Constant)
        stakeFile = "owner.json";
        persistRootToken = "$persistRoot";
        pathChars = "~.-_:@";
        pathSep = unique("/"+string(filesep));
        encodeChars = "@#*[]&()";
    end

    properties (Access = private)
        folder
    end

    methods (Static)

        function folder = Initialize(sid,config)
        %Initialize Create a folder for storing persistent data.

            import prodserver.mcp.io.Scheme
            import prodserver.mcp.io.uri.File
            

            config = Scheme.TokenizeConfiguration(fileTokens(),config);

            folder = sessionRootFolder(sid,config);
            ex = exist(folder,"file");  % File or folder
            if ex ~= 7 && ex ~= 2
                [ok,msg] = mkdir(folder);
                if ok == false
                    error("prodserver:mcp:SessionRootUnavailable", ...
   "Unable to create or access session root '%s' for '%s' scheme: %s.", ...
                        folder, "prodserver.mcp.io.File", msg);
                end
                stake.createdAt = datetime("now");
                tokens = Scheme.Tokens();
                stake.pipeline = tokens(Scheme.pipelineToken);
                writestruct(stake,fullfile(folder,File.stakeFile));
            elseif ex == 2
                error("prodserver:mcp:SessionRootUnavailable", ...
   "Unable to create or access session root '%s' for '%s' scheme: %s.", ...
                        folder, "prodserver.mcp.io.File", ...
                        "Root exists as a file (not a folder) already.");
            end
        end

        function Terminate(sid,config)
        %Terminate Remove the folder used for storing persistent data. This
        %deletes all the persistent data.
            
            import prodserver.mcp.io.Scheme

            config = Scheme.TokenizeConfiguration(fileTokens(),config);

            folder = sessionRootFolder(sid,config);  
            if exist(folder,"dir") ~= 7
                error("prodserver:mcp:SessionRootUnavailable", ...
   "Unable to create or access session root '%s' for '%s' scheme: %s.", ...
                    folder, "prodserver.mcp.io.File", ...
                    "Folder not found.");
            end
            [ok, msg] = rmdir(folder,'s');
            if ok == false
                error("prodserver:mcp:SessionRootPersists", ...
    "Unable to clear or remove session root '%s' for '%s' scheme: %s.", ...
                    folder, "prodserver.mcp.io.File", ...
                    msg);
            end
        end

        function pth = FileURI2Path(uri)
        %FileURI2Path Convert a File URI to a platform-specific filesystem
        %path. For example:
        %  file:/C:/path/to/storage/X.mat  
        %becomes
        %  C:/path/to/storage/X.mat

            
            import prodserver.mcp.validation.istext

            persistent driveLetter
            if isempty(driveLetter)
                driveLetter = textBoundary("start") + "/" + ...
                    lettersPattern(1) + ":";
            end

            % Parse strings to URI structures.
            if istext(uri)
                uri = prodserver.mcp.io.parseURI(uri);
            end

            % Extract the path from the URI, validate the scheme
            if isstruct(uri)
                isFile = strcmp([uri.scheme],"file");
                if ~all(isFile)
                    fnf = find(isFile == false,1,"first");
                    error("prodserver:mcp:UnexpectedScheme", ...
 "Unexpected scheme '%s' in URI %s. URI must begin with scheme 'file:'.", ...
                        uri(fnf).scheme,uri(fnf).uri);
                end
                pth = [uri.path];
            else
                error("prodserver:mcp:BadURIType", ...
  "Invalid URI type %s. URIs must be a string or character vector.", ...
                    class(uri(1)));
            end

            if ispc
                % Change prefix /C:/ to C:/ -- remove leading /
                startsWithDriveLetter = startsWith(pth,driveLetter);
                pth(startsWithDriveLetter) = ...
                    extractAfter(pth(startsWithDriveLetter),1);
            end

            % Restore percent-encoded characters
            pth = prodserver.mcp.io.percentDecode(pth);
        end
    end

    methods
        function fs = File(varargin)
        %File Create a file scheme object. Configure object and attach to
        %existing persistent storage, which must already exist.
        % 
        %Note that the lifecycle of the associated persistent storage is 
        %independent of the lifecycle of this object, deliberately, which 
        %allows persistent storage to "persist" between calls to stateless 
        %worker processes. 

            tokens = fileTokens();
            fs = configure(fs, fileparts(mfilename("fullpath")), ...
                tokens,varargin{:});
        end

        function delete(fs)
        %delete Clean up instance-specific data.
            detach(fs);
        end

        function u = rerootURI(s,uri,root)
        % rerootURI Change the root of the URI's path.

            import prodserver.mcp.internal.Constants

            % Forward slash only in the path part of the URI.
            root = replace(root,filesep,Constants.URISep);

            u = rerootURI@prodserver.mcp.io.Scheme(s,uri, ...
                root);
        end

        function u = defaultURI(fs,var,~)
        %defaultURI Construct defaultURI for var under the file scheme.
        %Ignore any value input, since the value of a variable never
        %appears in the file:// URI.
            import prodserver.mcp.internal.Constants
            

            if isempty(fs.folder)
                error("prodserver:mcp:SessionUninitialized", ...
                    "%s scheme session is uninitialized.", class(fs));
            end

            % <scheme>: Don't add any / since by default we have no
            % authority.
            scheme = prefix(fs);

            % normalizeConfig lowercases all field names.
            peFolder = replace(fs.folder,filesep,Constants.URISep);
            peFolder = prodserver.mcp.io.percentEncode( ...
                peFolder,skip=fs.pathSep);
            u = scheme + (peFolder + Constants.URISep) + var;
            addExt = ~endsWith(var,Constants.ExtensionPattern);
            if any(addExt)
                u(addExt) = u(addExt) + (Constants.ExtSep + fs.configuration.defaults.ext);
            end

            % var or folder may have characters that need percent-encoding.
            u = prodserver.mcp.io.percentEncode(u,...
                extra=fs.encodeChars);
        end

        function tf = conforms(fs,uri,varargin)
        %conforms Does the URI syntatically conform to the File scheme?
            tf = conforms@prodserver.mcp.io.Scheme(fs, ...
                uri,pathChars=fs.pathChars,pathSep=fs.pathSep);
        end

        function tf = exist(fs,uri)
        %exist Does the URI exist in the scheme?
            import prodserver.mcp.internal.Constants

            if isempty(uri)
                tf = false;
                return;
            end

            % Which URIs conform to this scheme?
            tf = conforms(fs,uri);

            % All the URIs with this scheme's prefix
            uri = uri(tf);

            % The URI exists in the file scheme if its path is a file 
            % that exists.
            stf = false(size(uri));
            for n = 1:numel(uri)      
                u = prodserver.mcp.io.parseURI(uri(n));
                stf(n) = exist(u.path,"file") == 2;
            end

            % Some of the URIs that are in this scheme might not have
            % values -- change them from true to false.
            tf(tf) = stf(n);
        end

        function tf = isactive(fs)
        %isactive Has the file scheme been activated?
            tf = ~isempty(fs.folder);
        end

        function fs = activate(fs)
        %activate Begin accepting storage requests. Attach to the
        %persistent storage area created by Initialize.

            

            if isKey(fs.tokens,fs.sessionIdToken)
                srf = sessionRootFolder(fs.tokens(fs.sessionIdToken), ...
                    fs.configuration);
                fs.tokens(fs.sessionRootToken) = srf;
            else
                error("prodserver:mcp:SessionUnknown", ...
                    "Session ID not specified.");
            end
         
            fs = attach(fs);

        end

        function fs = deactivate(fs)
        %deactivate Stop accepting storage requests for the current
        %session. 
            fs = detach(fs);
        end

        function fs = clear(fs)
        %clear Remove persistent session data.
            

            dotDir = [".", ".."];

            function [ok,msg] = removeData(folder)
            % Remove all the files in folder. Recursively descend.

                % All the files in folder.
                d = dir(folder);

                % Don't delete pwd or its parent. Deleting the parent would
                % eventually delete the entire file system. No fun at all,
                % that.
                skip = ismember({d.name},dotDir);
                d = d(~skip);

                % Delete every file. Recursively delete all subfolders.
                for x = d'
                    f = fullfile(x.folder,x.name);
                    if isfolder(f)
                        [ok,msg] = removeData(f);
                        if ok == false
                            error("prodserver:mcp:SessionDataPersists", ...
 "Unable to clear or remove session data in %s for %s scheme: %s", ...
                                x.folder, class(fs), msg);
                        end
                        [ok,msg] = rmdir(f);
                        if ok == false
                            error( ...
  "Unable to clear or remove session root %s for %s scheme: %s", ...
                                x.folder, class(fs), msg);
                        end
                    else
                        delete(f);
                    end
                end

                % Assume all is well.
                ok = true;
                msg = "";

                % Trust, but verify
                d = dir(folder);
                if numel(d) > 2
                    ok = false;
                    msg = sprintf("%d files not deleted.", ...
                        numel(d) - numel(dotDir));
                end
            end

            if exist(fs.folder,"dir") == 7
                [ok,msg] = removeData(fs.folder);
                if ok == false
                    error("prodserver:mcp:SessionDataPersists", ...
      "Unable to clear or remove session data in %s for %s scheme: %s", ...
                        fs.folder, class(fs), msg);
                end 
            else
                error("prodserver:mcp:SessionRootUnavailable", ...
      "Unable to create or access session root %s for %s scheme: %s", ...              
                    fs.folder, class(fs), "Folder not found.");            
            end
        end
    end
    methods (Access = protected)

        function fs = attach(fs)
            %attach "Attach" to the existing folder, which must exist.
            

            fs.folder = fs.tokens(fs.sessionRootToken);
            if exist(fs.folder,"dir") ~= 7
                error("prodserver:mcp:SessionRootUnavailable", ...
      "Unable to create or access session root %s for %s scheme: %s", ...  
                    fs.folder, class(fs), "Folder not found.");
            end
        end

        function fs = detach(fs)
            %detach Detach from the existing folder. 
            

            fs.folder = string.empty;
        end
    end
end

function folder = sessionRootFolder(sid,config)
%Determine location of session root folder.
%
%  1) If $sessionRoot is already set, use that location.
%  2) If $persistRoot exists, use $persistRoot/$sessionId
%  3) Use the $defaultPersistRoot/$sessionId

    import prodserver.mcp.io.uri.File
    import prodserver.mcp.io.Scheme

    tokens = Scheme.Tokens();
    if isKey(tokens, File.sessionRootToken)
        folder = tokens(File.sessionRootToken);
    else
        sid = prodserver.mcp.orchestrator.parseSessionID(sid);
        sid = sanitizeForPath(sid);
        if isKey(tokens, File.persistRootToken)
            folder = fullfile(tokens(File.persistRootToken),sid);
        else
            folder = fullfile(config.defaults.persistroot,sid);
        end
    end
end

function str = sanitizeForPath(str)
%sanitize Make str safe to use as part of a path on the file system. No
%wildcard or regular expression characters, for example. 
    forbidden = "*?()!+\/";
    str = strrep(str,forbidden,"_");
end

function tokens = fileTokens()
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.io.uri.File

    % Any persistence root location must be "well-known" -- that is,
    % discoverable or deducible from some invariant first principles. It
    % must remain constant between calls to the pipeline's components. When
    % deployed to MATLAB Production Server, that implies a location that
    % will persist between and can be shared by multiple workers.

    % The File scheme uses the system temporary directory.

    tokens = prodserver.mcp.internal.DictionaryHandle( ...
        "string","string");
    % file_persist won't create folders starting with C:\, but C:/ works.
    % percentEncode in case of spaces in the path.
    persistFolder = replace(tempdir,"\",Constants.URISep);
    persistFolder = replace(persistFolder,"/"+textBoundary("end"),"");
    tokens(File.persistRootToken) = persistFolder;
end

% Introduced from / by File.yaml. Called indirectly. MATLAB Compiler will
% never find them without this hint.

%#function prodserver.mcp.io.importVariable
%#function prodserver.mcp.io.exportVariable