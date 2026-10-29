function tf = isInstalledPackageFolder(folder)
%isInstalledPackageFolder Which of the members of folder belong to an
%installed MATLAB package (an add-on installed from a toolbox file, for
%example)? A package's folders are its root and the member folders its
%definition lists. MATLAB requires them to stay on the path together and in
%order, so callers mustn't add, remove or move them one at a time.

% Copyright 2026 The MathWorks, Inc.

    arguments
        folder string
    end

    import prodserver.mcp.internal.canonicalFolder

    % Package roots are absolute and member folders are relative to them,
    % so the names need no file system lookups.
    members = strings(1,0);
    pkgs = mpmlist;
    for p = 1:numel(pkgs)
        root = string(pkgs(p).PackageRoot);
        members = [members, root]; %#ok<AGROW>
        for f = 1:numel(pkgs(p).Folders)
            members = [members, fullfile(root, pkgs(p).Folders(f).Path)]; %#ok<AGROW>
        end
    end
    tf = ismember(canonicalFolder(folder), ...
        canonicalFolder(members, resolve=false));
end
