classdef DictionaryHandle < handle & matlab.mixin.indexing.RedefinesParen & ...
        matlab.mixin.indexing.RedefinesDot
%DictionaryHandle Shareable dictionary. Wraps a dictionary in handle
%semantics.

% Copyright 2025, The MathWorks, Inc.

    properties (Access=private)
        kvMap
    end

    properties(Dependent,SetAccess=immutable)
        Count
    end

    methods
        function dh = DictionaryHandle(keyType,valueType)
            arguments
                keyType string
                valueType string
            end
            dh.kvMap = configureDictionary(keyType,valueType);
        end

        %
        % Dependent properties
        % 
        function n = get.Count(dh)
            n = numEntries(dh.kvMap);
        end

        %
        % Clone dictionary interface.
        %

        function k = keys(dh)
            k = keys(dh.kvMap);
        end

        function v = values(dh)
            v = values(dh.kvMap);
        end

        function t = entries(dh)
            t = entries(dh.kvMap);
        end

        function [kt,vt] = types(dh)
            [kt,vt] = types(dh.kvMap);
        end

        function n = numEntries(dh)
            n = numEntries(dh.kvMap);
        end

        function tf = isKey(dh,key)
            tf = isKey(dh.kvMap,key);
        end

        %
        % Handle semantics: no return values required.
        %

        function merge(dh,varargin)
            if nargin > 1
                donor = varargin{1};
                e = entries(donor);
                if height(e) > 0
                    insert(dh,e.Key,e.Value);
                end
                % Keep going as long as there are more inputs to merge into
                % this dictionary.
                merge(dh,varargin{2:end});
            end
        end

        function insert(dh,key,value)
            dh.kvMap(key) = value;
        end

        function remove(dh,key)
            dh.kvMap(key) = [];
        end

        %
        % RedefinesDot
        %


        % 
        % RedefinesParen
        %

        function out = cat(varargin)
            N = nargin;
            % Dictionaries must have compatible key and value types.
            [kt,vt] = types(varargin{1});
            out = prodserver.mcp.internal.DictionaryHandle(kt,vt);
            for n = 1:N
                dhc = varargin{n};
                k = keys(dhc);
                insert(out,k,dhc(k));
            end
        end

        function sz = size(dh,varargin)
            sz = size(dh.kvMap);
        end

    end

    methods (Access=protected)

        function varargout = dotReference(dh,indexOp)
            key = indexOp.Name;
            [varargout{1:nargout}] = dh(key);

            % Remove extra level of cell array required for heterogeneous
            % storage.
            [~,t] = types(dh.kvMap);
            if strcmpi(t,"cell")
                for n = 1:nargout
                    v = varargout{n};
                    varargout{n} = v{1};
                    if length(indexOp) > 1
                        varargout{n} = varargout{n}.(indexOp(2:end));
                    end
                end
            end
        end

        function dh = dotAssign(dh,indexOp,value)

            key = indexOp(1).Name;
            [~,t] = types(dh.kvMap);
            if strcmpi(t,"cell") 
                if length(indexOp) > 1
                    obj = dh.(indexOp(1));
                    obj.(indexOp(2:end)) = value;       
                    dh.(indexOp(1)) = obj;
                else
                    dh(key) = { value };
                end
            else
                dh(key) = value;
            end
        end

        function n = dotListLength(dh,indexOp,indexContext)

            % If the elements of the dictionary are heterogeneous (as
            % indicated by value type "cell"), the dotlistlength is
            % determined by applying operations 2:end to whatever is stored
            % in the dictionary.

            [~,t] = types(dh.kvMap);
            if strcmpi(t,"cell") && length(indexOp) > 1
                item = dh.kvMap(indexOp(1).Name);
                n = listLength(item{1},indexOp(2:end),indexContext);
            else
                n = listLength(dh.kvMap,indexOp,indexContext);
            end
        end


        function varargout = parenReference(dh,indexOp)
            args = extractArguments(indexOp);
            [varargout{1:nargout}] = dh.kvMap(args{:});
        end

        function dh = parenAssign(dh,indexOp,varargin)
            args = extractArguments(indexOp);
            [dh.kvMap(args{:})] = varargin{:};
        end

        function n = parenListLength(dh,indexOp,ctx)
            n = listLength(dh.kvMap,indexOp,ctx);
        end

        function parenDelete(dh,indexOp)
            args = extractArguments(indexOp);
            dh.kvMap(args{:}) = [];
        end

    end

end

function args = extractArguments(indexOp)
    args = cell(1,numel(indexOp.Indices));
    for n = 1:numel(args)
        args{n} = indexOp.Indices{n};
    end
end