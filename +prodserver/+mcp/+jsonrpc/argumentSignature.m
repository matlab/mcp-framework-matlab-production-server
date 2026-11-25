function [validation, default, matlabClass] = argumentSignature(description)
%argumentSignature A parameter's signature entries, from its arguments
%   block line.
%   [validation, default, matlabClass] = argumentSignature(description)
%   reads DESCRIPTION, the parameter's entry in the descriptions map, and
%   returns what /signature reports for it:
%
%     validation  struct with fields size, type and fcn: the declared size,
%                 such as "(1,:)", the class, "" if none, and the validator
%                 functions. [] for a parameter with no validation.
%     default     The default value's text, such as "2", or "".
%     matlabClass The declared class, or "" if none.
%
%   One reader for both ways a definition is made, from the arguments
%   block alone (argumentDeclaration) and from example calls too
%   (SchemaObserver), so that the two report the same signature.

% Copyright 2026 The MathWorks, Inc.

    validation = [];
    default = "";
    matlabClass = "";
    if prodserver.mcp.internal.hasField(description, "validation") && ...
            strlength(description.validation) > 0
        [sz, t, f, default] = argumentInfo(description.validation);
        if isempty(t)
            t = "";
        end
        validation = struct("size", sz, "type", t, "fcn", f);
        matlabClass = string(t);
    end
end

function [size,type,fcn,default] = argumentInfo(info)
% The argument information line (a string) consists of four optional parts:
% <size> <class> <validation> <default>
% <size> is delimited by ( ).
% <class> is a single string, with no spaces.
% <validation> is delimited by { }.
% <default> begins with =.

    import prodserver.mcp.internal.Constants

    % When erasing parts of the string, use the patterns instead of the
    % literal text in order to anchor the erasure to the beginning of the
    % string. In the info line 'string = string.empty' we must ONLY erase
    % the first 'string' or the default value will be set to '.empty',
    % which is invalid MATLAB code.

    size = extract(info,Constants.ParameterSizePattern);
    info = strtrim(erase(info,Constants.ParameterSizePattern));

    type = extract(info,Constants.TypePattern);
    info = strtrim(erase(info,Constants.TypePattern));

    fcn = extract(info,Constants.ValidationPattern);
    info = strtrim(erase(info,Constants.ValidationPattern));

    default = strtrim(extract(info,Constants.DefaultPattern));
end
