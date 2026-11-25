classdef ClientCapabilities
%ClientCapabilities What an MCP client declared it supports.
%   The same whatever protocol revision the client speaks: each revision's
%   adapter builds one from wherever its revision keeps the client's
%   capabilities. Handlers ask it questions, by the spec's names:
%
%       supports(caps, "io.modelcontextprotocol/ui")
%       extension(caps, "io.modelcontextprotocol/ui").mimeTypes
%
%   caps = ClientCapabilities(declared) takes the capabilities object as
%   jsondecode returned it. jsondecode renames JSON names that aren't valid
%   MATLAB field names, so io.modelcontextprotocol/ui arrives as
%   io_modelcontextprotocol_ui. supports and extension rename the ID they
%   are given the same way before looking it up, so callers always use the
%   spec's IDs.
%
%   The renaming can make two IDs collide, a.b/c and a_b_c for example:
%   jsondecode then names the second one a_b_c_1, and only the first is
%   found by its ID. Real extension IDs are reverse-domain names, so this
%   is unlikely.
%
%   ClientCapabilities.none() is a client that declared nothing. So is a
%   declaration that isn't a JSON object: the client's data isn't trusted to
%   be well formed.

% Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = immutable)
        % Core capabilities: the client's settings for each, or [] if it
        % didn't declare it. A capability declared with no settings, {} in
        % JSON, is a struct with no fields.
        Roots = []
        Sampling = []
        Elicitation = []
        Experimental = []
    end

    properties (Access = private)
        % Renamed extension ID -> the extension's settings, in a cell.
        Extensions dictionary = configureDictionary("string", "cell")
    end

    methods
        function caps = ClientCapabilities(declared)
            arguments
                declared = struct()
            end

            if ~isstruct(declared) || ~isscalar(declared)
                return
            end

            core = ["roots", "sampling", "elicitation", "experimental"];
            props = ["Roots", "Sampling", "Elicitation", "Experimental"];
            for n = 1:numel(core)
                if isfield(declared, core(n))
                    caps.(props(n)) = declared.(core(n));
                end
            end

            if isfield(declared, "extensions") && ...
                    isstruct(declared.extensions) && isscalar(declared.extensions)
                ext = declared.extensions;
                ids = string(fieldnames(ext));
                for n = 1:numel(ids)
                    caps.Extensions(ids(n)) = {ext.(ids(n))};
                end
            end
        end

        function tf = supports(caps, id)
        %supports True if the client declared the extension named ID.
            arguments
                caps
                id (1,1) string
            end
            tf = isKey(caps.Extensions, fieldName(id));
        end

        function settings = extension(caps, id)
        %extension The client's settings for the extension named ID, or []
        %if it didn't declare it. An extension declared with no settings
        %is a struct with no fields.
            arguments
                caps
                id (1,1) string
            end
            key = fieldName(id);
            if isKey(caps.Extensions, key)
                settings = caps.Extensions{key};
            else
                settings = [];
            end
        end
    end

    methods (Static)
        function caps = none()
        %none A client that declared no capabilities.
            caps = prodserver.mcp.protocol.ClientCapabilities();
        end
    end
end

function name = fieldName(id)
% The field name jsondecode gives the JSON name ID.
    name = string(matlab.lang.makeValidName(id));
end
