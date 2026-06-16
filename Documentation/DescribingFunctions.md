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

## Comment Type and Location
The build process collects comments in order to **describe** your MCP tool and **declare** its input and output parameters.

**Tool description**: The first contiguous block of comment lines following the MATLAB function line becomes the tool description. Any non-comment line terminates the description -- this includes blank lines. For example:
```MATLAB
function img = drawvector(bbox, vectors)
% DRAWVECTOR Turtle Graphics for MATLAB. 
%
% The input vector list specifies a vector path. The end point of vector N is
% the origin of vector N+1. Draw the vector path, and then draw the bounding
% box. The output img is a width-by-height x 3 matrix of pixel colors.

% Copyright 2025, The MathWorks
```
The first five comment lines are copied verbatim into the MCP tool description. The blank line terminates the comment block. The copyright line does not appear in the description.

**Parameter declaration**: Parameter declarations are drawn from the `arguments` blocks. 
```MATLAB
    arguments(Input)
        bbox double    % Bounding box that contains the vectors
        vectors double % Turtle graphics vectors
    end
    arguments(Output)
        % A five dimensional array specifying the color values at each pixel of the
        % image. Width x Height X [R,G,B], where R=Red, G=Green and B=Blue.
        img double 
    end
```
Each input argument is described by a concise comment *to the right* of the argument's name and type. The output argument requires a two-line comment, which appears *above* the argument's name and type. MCP Framework recognizes both styles and will capture either. You may mix the two styles in the same comment block -- some arguments with comments to the right, some with comments above. 

The first blank or non-comment line terminates the argument description block -- which means the comment and the argument must be contiguous. The comment may not be separated from the argument by a blank line.

## Optional Arguments
MATLAB argument blocks support [optional arguments](https://www.mathworks.com/help/matlab/matlab_prog/validate-name-value-arguments.html) via name-value pairs at the end of the argument list. Optional arguments require comments just like required arguments.

MCP Framework supports optional arguments declared in `arguments` blocks. MATLAB's `varargin` is not supported. Note the use of both *to-the-right* and *above* comments. 

```MATLAB
function img = drawvector(bbox,vectors,options)
% DRAWVECTOR Turtle Graphics for MATLAB. 

    arguments (Input)
        bbox double                        % Bounding box that contains the vectors
        vector double                      % Turtle graphics vectors
        options.width (1,1) double = 300   % Width, in pixels of the generated JPG image
        options.height (1,1) double = 300  % Height, in pixels, of the generated JPG image

        % Full path to a file in which to save the JPG image. If empty, the image 
        % data is returned in the output "img".
        options.file (1,1) string = string.empty.  
    end
```

