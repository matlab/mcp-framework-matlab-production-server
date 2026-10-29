classdef WireSupport
% WireSupport Which wire encodings can carry values of a MATLAB class.
%   WireSupport.of(matlabClass) returns:
%
%     JSON        Both encodings carry it, as a plain JSON value.
%     Converted   Both encodings carry it, but plain JSON only by
%                 converting it: a datetime as ISO 8601 text (format
%                 "date-time"), a duration as a number of seconds. See
%                 jsonTimeSchema and decodeJSONValues.
%     Invertible  Only the invertible encoding carries it.
%     None        Neither carries it.
%
%   WireSupport.of(matlabClass, typemap) is also JSON for any class TYPEMAP
%   names: the user has mapped it to a JSON type.
%
%   The class lists are in prodserver.mcp.internal.Constants. The Converted
%   and Invertible classes are the ones mcpWireEncodeValue and
%   mcpWireDecodeValue round-trip.

% Copyright 2026 The MathWorks, Inc.

    enumeration
        JSON
        Converted
        Invertible
        None
    end

    methods (Static)
        function support = of(matlabClass, typemap)
            arguments
                matlabClass (1,1) string
                typemap struct = struct()
            end
            import prodserver.mcp.internal.Constants
            import prodserver.mcp.jsonrpc.WireSupport
            if ismember(matlabClass, Constants.JSONClasses) || ...
                    (~isempty(typemap) && isfield(typemap, matlabClass))
                support = WireSupport.JSON;
            elseif ismember(matlabClass, Constants.ConvertedClasses)
                support = WireSupport.Converted;
            elseif ismember(matlabClass, Constants.InvertibleClasses)
                support = WireSupport.Invertible;
            else
                support = WireSupport.None;
            end
        end

        function text = supportedClasses()
        %supportedClasses The classes a parameter may have, for messages.
            import prodserver.mcp.internal.Constants
            text = "numeric types, logical, strings, cell arrays, " + ...
                "structures, " + prodserver.mcp.internal.andList(Constants.ConvertedClasses) + ...
                " and, with encoding=""Invertible"", " + ...
                prodserver.mcp.internal.andList(Constants.InvertibleClasses);
        end

        function names = classNames()
        %classNames Every class some encoding carries, by name.
            import prodserver.mcp.internal.Constants
            names = [Constants.JSONClasses, Constants.ConvertedClasses, ...
                Constants.InvertibleClasses];
        end
    end
end
