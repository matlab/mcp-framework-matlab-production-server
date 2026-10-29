function outputs = assembleOutputs(tool, endpoint, def, sig, data, nout, encoding)
%assembleOutputs Turn a tools/call result into prodserver.mcp.call's outputs.
%   OUTPUTS = assembleOutputs(TOOL, ENDPOINT, DEF, SIG, DATA, NOUT, ENCODING)
%   returns a cell array of output values for a call made with NOUT
%   outputs. DEF is the tool's tools/list entry, SIG the signature table
%   from the /signature endpoint, DATA the decoded JSON-RPC response and
%   ENCODING the tool's wire encoding.
%
%   Outputs are positional (v1.4.1's contract, adopted in conformance Phase
%   XA): ordered by the output schema's 'required' list first, then by any
%   further names the signature declares. That union is the only order both
%   sides agree on -- the field order jsondecode produces is the wire's.
%
%   A function of its own so the contract can be unit tested without a
%   server.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.jsonrpc.mcpDecode

    declared = prodserver.mcp.internal.requiredNames(def, "outputSchema");

    % Generated tools always send "required":[] for outputs, so the test is
    % for a non-empty list, not for the key.
    if ~isempty(declared) && ...
            ~hasField(data, "result.structuredContent")
        error("prodserver:mcp:NoStructuredContent", "Tool %s has required " + ...
            "outputs but did not produce structured content.", tool);
    end

    if hasField(data, "result.structuredContent")
        result = data.result.structuredContent;
        order = declared;
        if hasField(sig, tool + ".output.name")
            names = string(sig.(tool).output.name);
            order = union(order, names(:)', "stable");
        end

        if isempty(order)
            % Nothing says what the outputs are called, so there is no
            % defensible order to return them in. Refuse only if the caller
            % actually asked for something.
            if nout > 0
                error("prodserver:mcp:TooFewOutputs", "Tool %s at %s " + ...
                    "declares no outputs, so the %d requested cannot be " + ...
                    "ordered. Inform tool creator.", tool, endpoint, nout);
            end
            outputs = {};
            return
        end

        % A call made as a statement has nargout 0 and still wants one
        % output, in ans.
        wanted = max(nout, 1);

        if wanted > numel(order)
            error("prodserver:mcp:TooFewOutputs", "Tool %s at %s " + ...
                "declares %d output(s) (%s) but %d requested.", ...
                tool, endpoint, numel(order), strjoin(order, ", "), wanted);
        end

        % ORDER unions two sources, either of which may name something the
        % server did not send. Say which, rather than letting the field
        % index below raise MATLAB:nonExistentField, which names the field
        % but not the tool, the endpoint or the reason.
        present = string.empty;
        if isstruct(result)
            present = string(fieldnames(result));
        end
        absent = setdiff(order(1:wanted), present, "stable");
        if ~isempty(absent)
            error("prodserver:mcp:MissingOutputs", "Tool %s at %s did " + ...
                "not return declared output(s) %s.", tool, endpoint, ...
                strjoin(absent, ", "));
        end

        % Plain JSON carries datetimes as ISO 8601 text and durations as
        % seconds; the output schema says which values those are.
        if encoding == prodserver.mcp.WireEncoding.JSON && ...
                hasField(def, "outputSchema")
            [result, msg] = prodserver.mcp.jsonrpc.decodeJSONValues( ...
                def.outputSchema, result, "Output");
            if strlength(msg) > 0
                error("prodserver:mcp:UndecodableOutput", ...
                    "Tool %s at %s returned an invalid value. %s.", ...
                    tool, endpoint, msg);
            end
        end

        % Outputs beyond those requested are dropped, as for any MATLAB
        % function.
        vals = cell(1, wanted);
        for n = 1:wanted
            vals{n} = result.(order(n));
        end
        outputs = mcpDecode(encoding, vals{:});
        outputs = reshape(outputs, 1, []);
    elseif hasField(data, "result.content")
        outputs = {data.result.content};
    else
        outputs = {};
    end
end
