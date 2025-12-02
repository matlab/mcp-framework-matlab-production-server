function mf = metafunction(fcn)
%metafunction Parse fcn and extract signature and descriptive data.
%Reconcile the difference between 25b and 26a by returning the same
%structure in both releases.
%
%   Name        : String
%   FullPath    : String
%   Signature   : Structure with fields Inputs, Outputs 
%       Inputs  : Parameter structure
%       Outputs : Parameter structure
%
% This structure contains only the information required for generating
% MCP tool wrapper functions and definitions. It omits some data returned
% by metafunction in both releases and renames many of the fields used in
% 25b.

% Copyright 2025, The MathWorks, Inc.

    if isMATLABReleaseOlderThan("R2025b")
        releaseInfo = matlabRelease;
        error("prodserver:mcp:UnsupportedRelease", "MATLAB Release %s " + ...
            "not supported. MCP Framework requires R2025b or later.", ...
            releaseInfo.Release);
    end

    mf = [];
    if isMATLABReleaseOlderThan("R2026a")
        md = matlab.internal.metafunction(fcn);
        if isempty(md)
            return;
        end
        mf.Name = char(md.Name);
        mf.FullPath = string(md.Location);

        %
        % Capture description -- and make it match format used in R2026a.
        %

        dd = md.DetailedDescription;
        % Remove initial function name, if present.
        dd = erase(dd,textBoundary("start")+optionalPattern(whitespacePattern)+fcn);
       
        mf.Description = char(strtrim(...
            extract(dd,textBoundary("start")+wildcardPattern("Except",newline)+newline)));

        % Remove H1 line from detailed description
        dd = erase(dd,mf.Description);

        % Blank lines must consist of at most a newline.
        dd = erase(dd,lineBoundary("start")+optionalPattern(whitespacePattern) +...
            lookAheadBoundary(lineBoundary("end")));

        % Strip two leading space characters from each line. The 2025b
        % descriptions have extra spaces.
        dd = erase(dd,lineBoundary("start")+"  ");

        mf.DetailedDescription = char(strtrim(dd));

        % 
        % Convert R2025b parameter list descriptions into "normal" form --
        % same field names as R2026a.
        %

        mf.Signature.Inputs = normalize25bParameters(md.Signature.Inputs);
        mf.Signature.Outputs = normalize25bParameters(md.Signature.Outputs);
    else
        md = metafunction(fcn);
        if isempty(md)
            return;
        end
        mf.Name = md.Name;
        mf.Description = md.Description;
        mf.DetailedDescription = md.DetailedDescription;
        mf.FullPath = string(md.FullPath);

        % Edit out unused fields to make normalization easier.
        mf.Signature.Inputs = normalize26aParameters(md.Signature.Inputs);
        mf.Signature.Outputs = normalize26aParameters(md.Signature.Outputs);
    end

    

end

function normal = parameterList(n)
% Normalized (but empty) structure describing N parameters.
    void = cell(1,n);
    normal = struct("Identifier",void,"Required",void,"Validation",void, ...
        "DefaultValue",void,"SourceClass",void,"Description",void,...
        "DetailedDescription",void);
end

function normal = normalize25bParameters(params)
% Convert 25b parameter lists to the canonical form.

    normal = parameterList(numel(params));
    for n=1:numel(params)

        % char instead of string because {'...', '...' } counts as text
        % while { "...", "..." } does not. See calls to, e.g., setdiff.
        normal(n).Identifier.Name = char(params(n).Name);
        normal(n).Identifier.GroupName = char(params(n).NameGroup);

        normal(n).Required = strcmpi(params(n).Presence,"required") && ...
            strcmpi(params(n).Kind,"positional");

        if ~isempty(params(n).Validation)
            normal(n).Validation.Class = params(n).Validation.Class;
            normal(n).Validation.Size = params(n).Validation.Size;
        end

        normal(n).DefaultValue = params(n).DefaultValue;
        normal(n).Description = strtrim(params(n).Description);
        normal(n).DetailedDescription = strtrim(params(n).DetailedDescription);
    end
end

function normal = normalize26aParameters(params)
    normal = parameterList(numel(params));
    for n=1:numel(params)

        normal(n).Identifier = params(n).Identifier;
        normal(n).Required = params(n).Required;

        if ~isempty(params(n).Validation)
            normal(n).Validation.Class = params(n).Validation.Class;
            normal(n).Validation.Size = params(n).Validation.Size;
        end

        normal(n).DefaultValue = params(n).DefaultValue;
        normal(n).Description = strtrim(params(n).Description);
        normal(n).DetailedDescription = strtrim(params(n).DetailedDescription);
    end
end