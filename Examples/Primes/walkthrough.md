# Prime Sequences

Build an MCP tool from `primeSequence`, which generates four types of prime number sequences: balanced, Eisenstein, Gaussian, and isolated primes.

## The Function

`primeSequence` accepts a count and a sequence type, and returns a vector of primes matching that sequence definition.

```MATLAB
function seq = primeSequence(n, type)
% n   : Number of primes in the generated sequence
% type: Type of the sequence -- "balanced", "eisenstein", "gaussian", or "isolated"
% seq : The primes in the requested sequence
```

Test it locally:
```MATLAB
primeSequence(5, "balanced")
ans =
     5    53   157   173   211
```

## Build

Package `primeSequence` as an MCP tool. This function returns small numeric vectors, so no wrapper function is needed.

```MATLAB
ctf = prodserver.mcp.build("primeSequence", wrapper="None");
```

## Deploy

Upload to MATLAB Production Server.

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

## Verify

```MATLAB
prodserver.mcp.ping(endpoint)
ans =
    true

prodserver.mcp.exist(endpoint, "primeSequence", "Tool")
ans =
    true
```

## Test with MCP Protocol

Call the tool end-to-end using the same protocol an LLM uses.

```MATLAB
bpr = prodserver.mcp.call(endpoint, "primeSequence", 11, "balanced")'
bpr =
     5    53   157   173   211   257   263   373   563   593   607

epr = prodserver.mcp.call(endpoint, "primeSequence", 9, "eisenstein")'
epr =
     2     5    11    17    23    29    41    47    53
```

## Connect an MCP Client

Configure your MCP client to connect to the tool endpoint:

```json
{
  "mcpServers": {
    "primeSequence": {
      "url": "http://localhost:9910/primeSequence/mcp",
      "type": "http"
    }
  }
}
```

## Try a Prompt

> Generate the first 20 balanced primes and the first 20 isolated primes. Which primes appear in both sequences?

The LLM calls `primeSequence` twice with different type arguments and compares the results.

--- Copyright 2025-2026 The MathWorks, Inc. ---
