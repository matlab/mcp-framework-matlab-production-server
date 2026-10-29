function tag = wrapperTypeSchema(classes, io, admitted)
%wrapperTypeSchema The schema of a wrapper's "type" tag.
%   tag = wrapperTypeSchema(classes, io) is the schema of the "type" field
%   of the invertible wrapper (see wrapInvertible) for a parameter whose
%   MATLAB class is one of CLASSES, as declared or observed. IO is "input"
%   or "output".
%
%   An output is tagged with the class the server sends,
%   {"enum":["double"]}, or several if it may send several. (A one-element
%   enum, not const, which not every LLM provider's tool schemas support.)
%   An input may be tagged with any class the parameter's own class
%   converts from, as MATLAB's arguments block
%   does: every numeric class and logical for a numeric or logical
%   parameter (true + true is 2), and char or string for a string. Not
%   string for a char: a string array may be ragged, which a char array
%   can't be. A char, struct or cell is exactly that.
%
%   tag = wrapperTypeSchema(classes, io, admitted) is the tag for a
%   parameter with no class -- CLASSES empty -- whose validators admit only
%   the classes ADMITTED (see validatorClasses), such as the numeric ones
%   for {mustBeNumeric}. They are used as they are.
%
%   With no class known at all -- an unexercised parameter with no declared
%   class and no such validator, or a class the generic wrapper doesn't
%   carry, such as one a typemap maps -- the tag lists every class the
%   decoder knows (WireSupport.classNames). That is the one list of
%   discriminators: a class added to it is added here too.

% Copyright 2026 The MathWorks, Inc.

    arguments
        classes string
        io (1,1) string {mustBeMember(io, ["input" "output"])}
        admitted string = string.empty
    end

    import prodserver.mcp.internal.Constants

    classes = unique(classes(strlength(classes) > 0), "stable");
    if isempty(classes) || ~all(ismember(classes, Constants.JSONClasses))
        if isempty(admitted)
            admitted = prodserver.mcp.jsonrpc.WireSupport.classNames();
        end
        tag = struct('enum', {num2cell(admitted(:))});
        return
    end

    if io == "input"
        numeric = [Constants.NumericClasses "logical"];
        accepted = string.empty;
        for c = classes(:)'
            if ismember(c, numeric)
                accepted = [accepted numeric]; %#ok<AGROW>
            elseif c == "string"
                accepted = [accepted "char" "string"]; %#ok<AGROW>
            else
                accepted = [accepted c]; %#ok<AGROW>
            end
        end
        classes = unique(accepted, "stable");
    end

    tag = struct('enum', {num2cell(classes(:))});
end
