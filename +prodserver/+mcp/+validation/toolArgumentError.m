function msg = toolArgumentError(tool, args, encoding)
%toolArgumentError Check tools/call arguments against the tool's schema.
%   msg = toolArgumentError(tool, args, encoding) returns "" if every
%   field of ARGS (the params.arguments of a tools/call, as jsondecode
%   delivers it, before wire decoding) is an input of TOOL and its value
%   satisfies that input's schema in TOOL.inputSchema. Otherwise it returns
%   a message describing the first failure, in JSON terms: "Argument 'n':
%   expected number, got string."
%
%   The schema is the one the server publishes, read with MATLAB's array
%   rules: a scalar satisfies an array schema, since a MATLAB scalar is a
%   1x1 array. Under Invertible encoding, an argument whose schema is the
%   generic type, size and data wrapper may also be sent bare, and its
%   numeric data may include the strings "NaN", "Inf" and "-Inf", as
%   wire_encoding_rules.txt allows (see wrapperAlternatives).
%
%   Missing required arguments are not checked here.

% Copyright 2026 The MathWorks, Inc.

    arguments
        tool (1,1) struct
        args (1,1) struct
        encoding (1,1) prodserver.mcp.WireEncoding
    end

    import prodserver.mcp.internal.hasField

    msg = "";
    names = string(fieldnames(args))';
    props = struct();
    if hasField(tool, "inputSchema.properties") && ...
            isstruct(tool.inputSchema.properties)
        props = tool.inputSchema.properties;
    end
    declared = string(fieldnames(props))';

    % Every argument must be one of the tool's inputs.
    unknown = setdiff(names, declared, "stable");
    if ~isempty(unknown)
        if isempty(declared)
            msg = sprintf("Tool '%s' takes no inputs, but received '%s'.", ...
                tool.name, strjoin(unknown, "', '"));
        else
            msg = sprintf("Tool '%s' has no input named '%s'. Its inputs " + ...
                "are: %s.", tool.name, strjoin(unknown, "', '"), ...
                strjoin(declared, ", "));
        end
        return
    end

    for name = names
        s = props.(name);
        value = args.(name);
        % The generic wrapper, or its published anyOf with the bare forms
        % (see allowBareForms): the same alternatives either way.
        [published, bare, wrapped] = prodserver.mcp.jsonrpc.bareOrWrapped(s);
        if encoding == prodserver.mcp.WireEncoding.Invertible && ...
                (published || prodserver.mcp.jsonrpc.isGenericWrapper(s))
            if ~published
                [bare, wrapped] = prodserver.mcp.jsonrpc.wrapperAlternatives(s);
            end
            if strlength(check(name, struct('anyOf', ...
                    {[bare; {wrapped}]}), value)) == 0
                continue
            end
            % It fits no form. Explain the failure against the form the
            % client evidently meant, not as "matches none of N schemas".
            if isstruct(value) || isempty(bare)
                s = wrapped;
            else
                s = bare{1};
            end
        end
        msg = check(name, s, value);
        if strlength(msg) > 0
            return
        end
    end
end

function msg = check(name, s, value)
% "" if value satisfies schema s, else the message for argument name.
    msg = "";
    detail = prodserver.mcp.validation.validateArgumentsWithSchema( ...
        struct('properties', struct(name, s)), name, {value});
    if strlength(detail) > 0
        msg = "Argument '" + name + "': " + jsonTerms(detail) + ".";
    end
end

function m = jsonTerms(m)
% The validator names MATLAB classes; a client sent JSON. Every numeric
% class is a JSON number here: the client chose the value, not the class.
    import prodserver.mcp.internal.Constants
    numeric = Constants.NumericClasses';
    words = [["char"; "string"; numeric; "logical"; "struct"; "cell"], ...
        ["string"; "string"; repmat("number", size(numeric)); "boolean"; ...
        "object"; "array"]];
    m = replace(m, "object (struct)", "object");
    for k = 1:size(words, 1)
        m = replace(m, "'" + words(k,1) + "'", words(k,2));
    end
end
