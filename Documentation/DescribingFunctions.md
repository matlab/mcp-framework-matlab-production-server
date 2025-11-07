# Describing MATLAB Functions
A good description of your function and its inputs and outputs is essential. The LLM relies on these
descriptions when deciding how to respond to a prompt. A good description is **complete** and 
**precise**:
* Complete: Lists all of the features of your tool, leaving nothing to the imagination.
* Precise: Explains all the details -- the types of the inputs and any restrictions or limits on their values.
The more detail you provide, the better the LLM will be able to decide when and how to use your tool.

If you provide this information to MCP Framework via comments and `argument` blocks in your code, 
MCP Framework can automatically generate the required MCP tool definition. For example, the 
`primeSequence` function begins with this code:

```MATLAB
function seq = primeSequence(n,type)
% Return the first N primes of the given sequence type. Four sequence types
% supported: Eisenstein, Balanced, Isolated and Gaussian.
    arguments(Input)
        n (1,1) double    % Length of the generated sequence
        type (1,1) string % Name of the sequence to generate
    end
    arguments(Output)
        seq double  % Generated sequence of prime numbers
    end
```
MCP Framework generates the MCP tool definition from this code. This information allows MCP Framework
to create a **complete** and **precise** definition because:

1. The comment following the function line describes the purpose of the tool and lists the range of its second input.
2. The argument blocks declare the **size** and **type** of each input and output.
3. Each argument's comment describes the information conveyed by the argument.

Also note that these comments and argument blocks will make your function easier to use in MATLAB, as the
desktop and editor will display them as hints and completions.

If you cannot add this information to your MATLAB functions, you must provide a complete MCP tool definition
to `prodserver.mcp.build` via the `definition` optional input. 
