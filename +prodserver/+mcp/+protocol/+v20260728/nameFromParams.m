function [name, required] = nameFromParams(jrpc)
%nameFromParams The body value Mcp-Name must mirror, and whether it is required.
%   NAME is the value this revision's Mcp-Name header has to carry for
%   JRPC, or "" when the body does not supply one. REQUIRED says whether
%   the request's method obliges it to carry one at all.
%
%   Both answers come from here because both sides of the wire need them and
%   need the same ones. The client emits the header from NAME; the server
%   compares the header against NAME. Spelled twice, the two copies would
%   agree on whatever the round-trip test happens to exercise and could
%   disagree on everything else -- which is the failure mode the round-trip
%   test exists to rule out, so it must not be the failure mode the test is
%   blind to.
%
%   The method list is part of the rule, not a separate fact: a header the
%   client omits for prompts/get and the server demands for prompts/get is a
%   -32020 on a valid request. One list, one caller-facing answer.
%
%   "" is returned for a method that requires a name but whose body omits
%   the field. That is not the same as "not required", and the two must not
%   be collapsed: the first is a bad request the header check has to reject
%   once presence is mandatory, the second is a request with nothing to
%   check.

% Copyright 2026 The MathWorks, Inc.

    name = "";
    required = false;

    if ~isstruct(jrpc) || ~isfield(jrpc, 'method')
        return
    end

    required = ismember(lower(string(jrpc.method)), ...
        ["tools/call", "resources/read", "prompts/get"]);

    if ~isfield(jrpc, 'params')
        return
    end
    p = jrpc.params;
    if ~isstruct(p)
        return
    end
    if isfield(p, 'name')
        name = string(p.name);
    elseif isfield(p, 'uri')
        name = string(p.uri);
    end
end
