classdef File < prodserver.mcp.io.Scheme
%File Marshalling configuration for the file:// scheme.
%
%Minimal class required by scheme extension framework.

% Copyright 2024-2026 The MathWorks, Inc.

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
        %FileURI2Path Convert a File URI to a platform-specific file system
        %path. For example:
        %  file:/C:/path/to/storage/X.mat  
        %becomes
        %  C:/path/to/storage/X.mat
        %
        %A URI whose path has a .. segment, or an encoded separator (%2F, or
        %%5C on Windows), is an error, prodserver:mcp:BadFilePath: no file
        %name needs either, and a client could use them to reach a file
        %outside the folder it names.
            
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

            % Change prefix /C:/ to C:/ -- remove leading /. Only valid on
            % Windows platform.
            if ispc
                startsWithDriveLetter = startsWith(pth,driveLetter);
                pth(startsWithDriveLetter) = ...
                    extractAfter(pth(startsWithDriveLetter),1);
            end

            % parseURI has already restored percent-encoded characters.
            % Decoding again would turn a literal %41 in a file name into A.

            encodedSeparator = ["%2F" "%2f"];
            if ispc
                encodedSeparator = [encodedSeparator "%5C" "%5c"];
            end
            for n = 1:numel(uri)
                rawPath = regexprep(uri(n).uri, "[?#].*$", "");
                if contains(rawPath, encodedSeparator) || ...
                        any(split(pth(n), "/") == "..")
                    error("prodserver:mcp:BadFilePath", ...
                        "Cannot read file URI %s: its path must not " + ...
                        "contain a '..' segment or an encoded separator.", ...
                        uri(n).uri);
                end
            end
        end

        function uri = Path2FileURI(pth)
        %Path2FileURI Convert a platform-specific file system path to a File
        %URI. The inverse of FileURI2Path: the URI parses with parseURI and
        %reads with deserialize. For example, on Windows:
        %  C:\path\to\my data\X.json
        %becomes
        %  file:///C:/path/to/my%20data/X.json
        %and the UNC path \\server\share\X.json becomes
        %  file:////server/share/X.json
        %
        %A relative path is made absolute against the current folder, and
        %a path from the root (\x) against its drive or UNC share. A
        %drive-relative path such as C:x is an error: its folder is the
        %current folder of drive C, which MATLAB doesn't know. Every character except unreserved characters, / and : is
        %percent-encoded as UTF-8, including %, # and ?, so no character
        %of a file name can change the meaning of the URI.

            arguments
                pth string
            end

            persistent drivePath driveRelative
            if isempty(drivePath)
                drivePath = textBoundary("start") + lettersPattern(1) + ":/";
                driveRelative = textBoundary("start") + lettersPattern(1) + ":" + ...
                    (textBoundary("end") | wildcardPattern(1, Except="/"));
            end

            uri = strings(size(pth));
            for n = 1:numel(pth)
                p = pth(n);
                if ismissing(p) || strlength(p) == 0
                    error("prodserver:mcp:BadFilePath", ...
                        "Cannot convert an empty path to a file URI.");
                end

                % Windows accepts both separators; a URI uses only /.
                % Elsewhere \ is an ordinary file name character, which
                % percent-encoding preserves.
                if ispc
                    p = replace(p, "\", "/");
                    % The long-path prefix \\?\ is not part of the path:
                    % \\?\C:\x is C:\x, \\?\UNC\server\share is a UNC path.
                    if startsWith(p, "//?/UNC/", IgnoreCase=true)
                        p = "//" + extractAfter(p, 8);
                    elseif startsWith(p, "//?/")
                        p = extractAfter(p, 4);
                    end
                end

                % Make the path absolute.
                if ispc
                    here = replace(string(pwd), "\", "/");
                    if startsWith(p, drivePath) || startsWith(p, "//")
                        % Drive or UNC path: already absolute.
                    elseif startsWith(p, driveRelative)
                        error("prodserver:mcp:BadFilePath", ...
                            "Cannot convert the drive-relative path '%s' " + ...
                            "to a file URI. Give the full path, starting " + ...
                            "%s\\.", pth(n), extractBefore(p, 3));
                    elseif startsWith(p, "/")
                        % Root of the current drive or UNC share.
                        p = driveRoot(here) + p;
                    else
                        p = here + "/" + p;
                    end
                elseif ~startsWith(p, "/")
                    p = string(pwd) + "/" + p;
                end

                % . and .. are resolved here, where the path is the local
                % user's own; FileURI2Path refuses .. from a client.
                p = prodserver.mcp.io.removeDotSegments(p);

                % A drive letter path needs a leading /: file:///C:/x. A UNC
                % path keeps its //, giving an empty authority and the path
                % //server/share: file:////server/share/x.
                if ispc && startsWith(p, drivePath)
                    p = "/" + p;
                end

                uri(n) = "file://" + prodserver.mcp.io.percentEncode(p, ...
                    except="/:");
            end
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

            % string: a char URI is one URI, not an array of characters.
            arguments
                fs
                uri string
            end

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
                % FileURI2Path, not the raw path: file:///C:/x has path
                % /C:/x, which is not a Windows file name.
                pth = prodserver.mcp.io.uri.File.FileURI2Path(uri(n));
                stf(n) = exist(pth,"file") == 2;
            end

            % Some of the URIs that are in this scheme might not have
            % values -- change them from true to false.
            tf(tf) = stf;
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
                            error("prodserver:mcp:SessionDataPersists", ...
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
        sid = prodserver.mcp.internal.parseSessionID(sid);
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

function root = driveRoot(folder)
% The drive (C:) or UNC share (//server/share) of FOLDER, with / separators.
    share = regexp(folder, "^//[^/]+/[^/]+", "match", "once");
    if ismissing(share) || strlength(share) == 0
        root = extractBefore(folder, 3);
    else
        root = share;
    end
end
