function [input,output] = parameterDescription(mf)
% parameterDescription Determine input and output parameter descriptions.
%
% Search the file for arguments blocks (which must be present) and extract
% any comments describing each individual argument (which also must be
% present).
%
% Return a dictionary for each type of parameter (input and output). The
% dictionary maps parameter names to a structure with two fields:
%   .description: Descriptive comment
%   .validation : class, size and function, as a string
%
% Assumes (requires!) that the arguments keyword and the (Input) or
% (Output) modifier are BOTH on the same line.
%
% Like this:
%    arguments(Input) 
% NOT like this:
%    arguments ...
%        (Input)
%
% (I don't even know if MATLAB allows that ... syntax. It shouldn't. But if
% it does, I explicitly disallow it here.)

% Copyright 2025, The MathWorks

    file = mf.FullPath;
    text = readlines(file);
    textLines = split(text,newline);

    % How many argument blocks are there in the function, and where are
    % they located? Look for arguments(Input) and arguments(Output) where
    % (Input) and (Output) are optional. Allow whitespace in reasonable
    % locations.
    space = optionalPattern(whitespacePattern);
    argPattern = textBoundary("start") + ...
        optionalPattern(whitespacePattern())+ ...
        "arguments" + optionalPattern( ...
            space + "(" + space + ("Output" | "Input") + space + ")") + ...
        space + ("%" | textBoundary("end"));
    pos = strfind(textLines,argPattern);
    argBlockStartLine = find(~cellfun('isempty',pos));

    % Find the starting offset of the input and output arguments blocks.
    inArgLine = 0;
    outArgLine = 0;
    if ~isempty(argBlockStartLine)
        % pos must have 1 or 2 elements
        if numel(argBlockStartLine) > 2
            error("prodserver:mcp:TooManyArgBlocks", ...
                "Too many arguments blocks in %s. Maximum allowed: 2. " + ...
                "Found %d.", mf.FullPath, numel(argBlockStartLine));
        end
        % Get the text of the first "arguments"-containing line.
        a = textLines(argBlockStartLine(1));
        % Trim comment, if any
        if contains(a,"%")
            a = extractBefore(a,"%");
        end
        % Undecorated arguments block or arguments(Input) is the input
        % block.
        if ~contains(a,"Output")
            inArgLine = argBlockStartLine(1);
            if numel(argBlockStartLine) == 2
                outArgLine = argBlockStartLine(2);
            end
        else
            % Unusual, but probably(?) allowed, outputs declared before
            % inputs.
            outArgLine = argBlockStartLine(1);
            if numel(pos) == 2
                inArgLine = argBlockStartLine(2);
            end
        end
    end

    % If the metafunction lists inputs, we required an inputs argument 
    % block for the description.

    if isempty(mf.Signature.Inputs) == false
        if inArgLine == 0
            error("prodserver:mcp:InputArgBlockRequired", ...
                "Function %s has inputs but %s contains no input " + ...
                "arguments block. Cannot create an MCP tool " + ...
                "without an input arguments block.",mf.Name,mf.FullPath);
        end
        % Build a dictionary mapping argument name to argument description.
        ad = argDescriptionFromBlock(textLines,inArgLine,mf.FullPath,"input");
        
        % Number of keys in ad must match number of input arguments.
        if numEntries(ad) ~= numel(mf.Signature.Inputs)
            error("prodserver:mcp:InputBlockSizeMismatch", ...
                "Number of arguments in input arguments block (%d) " + ...
                "does not match number of function inputs (%d).", ...
                numEntries(ad), numel(mf.Signature.Inputs));
        end

        % This dictionary maps input names to their descriptions.
        input = ad;
    else
        input = [];  
    end

    % if the metafunction lists outputs, we require an outputs argument
    % block for the description.

    if isempty(mf.Signature.Outputs) == false
        if outArgLine == 0
            error("prodserver:mcp:OutputArgBlockRequired", ...
                "Function %s has outputs but %s contains no output " + ...
                "arguments block. Cannot create an MCP tool " + ...
                "without an output arguments block.",mf.Name, mf.FullPath);
        end
        ad = argDescriptionFromBlock(textLines,outArgLine,mf.FullPath,"output");

        if numEntries(ad) ~= numel(mf.Signature.Outputs)
            error("prodserver:mcp:OutputBlockSizeMismatch", ...
                "Number of arguments in output arguments block (%d) " + ...
                "does not match number of function outputs (%d).", ...
                numEntries(ad), numel(mf.Signature.Outputs));
        end

        % This dictionary maps output names to their descriptions.
        output = ad;
    else
        output = [];
    end
end

function ad = argDescriptionFromBlock(textLines,argBlockLine,file,block)
% Find comments describing each argument in the argument block starting at
% pos.

    ad = configureDictionary("string","struct");

    % Search above and to the right for comments describing each argument
    % in the block. Allow multi-line comments above the argument, but only
    % single line comments to the right.
    space = optionalPattern(whitespacePattern);
    startPattern = textBoundary("start") + space;
    endPattern = space + "end" + space + (textBoundary("end") | "%");
    validationTerminator = "%" | textBoundary("end");
    argTerminator = whitespacePattern | validationTerminator;
    % All argument names begin with at least one letter or an underscore.
    argNamePattern = textBoundary("start") + space + ...
        (lettersPattern(1) | "_") + ...
        wildcardPattern + argTerminator;
    lastLine = numel(textLines);
    n = argBlockLine + 1;
    while n <= lastLine && matches(textLines(n),endPattern) == false
        if startsWith(textLines(n),argNamePattern)
            arg = extract(textLines(n),argNamePattern);
            arg = strtrim(arg);
            a.description = argDescriptionFromComment(textLines,n);
            a.validation = strtrim(...
                extractBetween(textLines(n),startPattern + arg,validationTerminator));
            ad(arg) = a;
        end
        n = n + 1;
    end

    % No description may be empty. Validation may be empty.
    for a = keys(ad)'
        d = ad(a).description;
        if isempty(d) || all(strlength(d) == 0)
            error("prodserver:mcp:ArgumentDescriptionMissing", ...
                "Missing description for %s argument %s in %s. Add a " + ...
                "descriptive comment above or to the right of the " + ...
                "declaration of %s.", block, a, file, a);
        end
    end

    % Name-value pair arguments are declared in "groups". opts.range, for
    % example, declares the "range" argument in the "opts" group. Add a
    % group name field to every entry. And remove the group prefix from the
    % names of any arguments in a group.
    names = keys(ad);
    for n = 1:numel(names)
        group = extract(names(n),textBoundary("start")+...
            wildcardPattern(Except='.')+lookAheadBoundary("."));
        if ~isempty(group)
            d = ad(names(n));                % metadata for argument names(n)
            d.group = group;                 % add group name field
            an = erase(names(n),group+".");  % remove group prefix
            ad = remove(ad,names(n));        % delete entry for names(n)
            ad(an) = d;                      % add entry for new name
        end
    end
end

function d = argDescriptionFromComment(textLines,n)
% Take all comment text above and to the right of the argument declaration.

    % Comment starting pattern
    space = optionalPattern(whitespacePattern);
    commentStart = textBoundary("start") + space + "%";

    % The easy one first -- anything after a % up to the end of the line.
    right = extractBetween(textLines(n), "%", textBoundary("end"));
    right = erase(right,commentStart);
    right = strtrim(right);

    % A comment line contains NOTHING but comment text.
    commentLinePattern = textBoundary("start") + space + "%" + ...
        wildcardPattern + textBoundary("end");

    % Keep backing up as long as we're looking at comment-only lines.
    % "If the line above is a comment, back up."
    cN = n;
    while cN > 1 && matches(textLines(cN-1),commentLinePattern)
        cN = cN - 1;
    end

    % Found comment(s) above.
    if cN < n 
        % Join all comment lines into one, minus the leading comment
        % character.
        above = textLines(cN:n-1);
        above = erase(above,commentStart);
        above = strtrim(above);
    else
        above = string.empty;
    end
    % English reading order: top-down, left to right.
    d = [above;right];
end

