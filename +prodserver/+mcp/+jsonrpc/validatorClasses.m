function classes = validatorClasses(validation)
%validatorClasses The classes an arguments block's validators admit.
%   classes = validatorClasses(validation) reads the validator functions in
%   VALIDATION, the text of an arguments block line or just its {...} part,
%   and returns the classes the ones it knows admit: the intersection, if
%   there are several. It returns string.empty if none of them is one it
%   knows, so the validators say nothing about the class.
%
%     mustBeNumeric                        the numeric classes
%     mustBeNumericOrLogical, mustBeInteger, mustBeReal,
%     mustBePositive, mustBeNonnegative    the numeric classes and logical
%     mustBeFloat                          double, single
%     mustBeText, mustBeNonzeroLengthText  char, string, cell (cellstr)
%     mustBeTextScalar                     char, string
%
%   Several of the numeric validators also admit char, as character codes;
%   char is left out, as it is for a parameter declared numeric (see
%   wrapperTypeSchema). For a parameter with no declared class, these are
%   the classes its wrapper's type may name.

% Copyright 2026 The MathWorks, Inc.

    arguments
        validation (1,1) string
    end

    import prodserver.mcp.internal.Constants
    numeric = Constants.NumericClasses;
    numericOrLogical = [numeric "logical"];
    text = ["char" "string" "cell"];
    table = dictionary( ...
        ["mustBeNumeric" "mustBeNumericOrLogical" "mustBeInteger" ...
         "mustBeReal" "mustBePositive" "mustBeNonnegative" "mustBeFloat" ...
         "mustBeText" "mustBeNonzeroLengthText" "mustBeTextScalar"], ...
        {numeric, numericOrLogical, numericOrLogical, ...
         numericOrLogical, numericOrLogical, numericOrLogical, ...
         Constants.FloatClasses, text, text, ["char" "string"]});

    classes = string.empty;
    names = validatorNames(char(validation));
    known = names(isKey(table, names));
    for k = 1:numel(known)
        admitted = table(known(k));
        if k == 1
            classes = admitted{1};
        else
            classes = intersect(classes, admitted{1}, "stable");
        end
    end
end


function names = validatorNames(text)
%validatorNames The names of the validators in the first {...} of TEXT:
%   the identifier that begins each item of the list. A validator's own
%   arguments may hold commas, brackets and braces -- mustBeMember(x,{'a'})
%   -- and quoted text may hold anything, so the list ends at the brace
%   that matches the first one, and splits only at commas outside any
%   brackets or quotes. Empty if there is no {...}.
    names = string.empty;
    start = find(text == '{', 1);
    if isempty(start)
        return
    end
    items = {};
    item = start + 1;
    depth = 0;
    quote = '';
    for k = start+1:numel(text)
        c = text(k);
        if ~isempty(quote)
            if c == quote
                quote = '';
            end
        elseif c == '"' || (c == '''' && ~isTranspose(text, k))
            quote = c;
        elseif any(c == '([{')
            depth = depth + 1;
        elseif any(c == ')]}')
            if depth == 0
                items{end+1} = text(item:k-1); %#ok<AGROW>
                break
            end
            depth = depth - 1;
        elseif c == ',' && depth == 0
            items{end+1} = text(item:k-1); %#ok<AGROW>
            item = k + 1;
        end
    end
    for n = 1:numel(items)
        name = regexp(items{n}, '^\s*([A-Za-z]\w*)', "tokens", "once");
        if ~isempty(name)
            names(end+1) = string(name{1}); %#ok<AGROW>
        end
    end
end


function tf = isTranspose(text, k)
%isTranspose Is the quote at TEXT(k) a transpose, not the start of text?
%   It is when it follows a name, a number, a closing bracket, a dot or
%   another transpose.
    before = strtrim(text(1:k-1));
    tf = ~isempty(before) && (isstrprop(before(end), 'alphanum') || ...
        any(before(end) == ')]}_.'''));
end
