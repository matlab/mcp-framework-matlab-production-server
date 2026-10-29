function uuid = archiveUUID(source)
%archiveUUID The compiler's UUID for an archive: discovery's archiveUuid.
%   uuid = archiveUUID() is the UUID of the archive this code runs in: the
%   MATLAB Runtime's AppComponentUUID user data (see getmcruserdata), set
%   for each archive the server loads. Empty when not deployed.
%
%   uuid = archiveUUID(ctf) is the UUID of the .ctf file CTF: the uuid
%   attribute of its .META/manifest.xml, which mcc never encrypts, whatever
%   the archive's protection (-s, -j, -k).
%
%   Both are "<archive>_<uuid>". mcc makes a new one for every build, so it
%   tells two builds of an archive apart, which a ping answer alone does not
%   (see deploy). Empty when there is no manifest or it can't be read: the
%   caller then can't tell builds apart, which is no worse than before.

% Copyright 2026 The MathWorks, Inc.

    arguments
        source string {mustBeScalarOrEmpty} = string.empty
    end

    if isempty(source)
        uuid = runningUUID();
    else
        uuid = ctfUUID(source);
    end
end


function uuid = runningUUID()
%runningUUID The UUID of the archive this code runs in. Outside the MATLAB
%Runtime, getmcruserdata returns empty.
    uuid = "";
    id = getmcruserdata('AppComponentUUID');
    if (ischar(id) || isstring(id)) && strlength(id) > 0
        uuid = string(id);
    end
end


function uuid = ctfUUID(ctf)
%ctfUUID The UUID in a .ctf file's manifest. unzip extracts every file in
%   the archive, which takes time and space in proportion to its size; the
%   internal extractArchive, which unzip calls, extracts the manifest alone.
    uuid = "";
    if ~isfile(ctf)
        return
    end
    out = string(tempname);
    mkdir(out);
    cleanup = onCleanup(@() rmdir(out, "s"));
    try
        % char only, and the entry's name with forward slashes: a string,
        % or a backslash, extracts nothing.
        matlab.io.internal.archive.extractArchive(char(ctf), char(out), ...
            'zip', {'.META/manifest.xml'}, char.empty);
    catch
        % Not a zip file: not an archive mcc built.
        return
    end
    uuid = manifestUUID(fullfile(out, ".META", "manifest.xml"));
end


function uuid = manifestUUID(manifest)
%manifestUUID The uuid attribute of a manifest's root element. Not its
%   container_uuid, which is usually empty.
    uuid = "";
    if ~isfile(manifest)
        return
    end
    try
        text = fileread(manifest);
    catch
        return
    end
    token = regexp(text, '<manifest\s[^>]*?(?<=\s)uuid="([^"]+)"', ...
        "tokens", "once");
    if ~isempty(token)
        uuid = string(token{1});
    end
end
