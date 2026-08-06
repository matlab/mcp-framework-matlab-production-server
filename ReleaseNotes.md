# 1.0: Nov 7, 2025
Initial release. Features:
* Create MCP server containing one MCP tool.
* Handwritten MCP tool description required.
* Externalizing large inputs and outputs via handwritten wrapper functions.

# 1.1: Dec. 2, 2025
* Build multiple tools into a single MCP server.
* Automatic generation of MCP tool description from function comments and argument blocks.
* Automatically externalize non-scalar inputs and outputs.
* Specify `ImportOptions` objects to deserialize externalized inputs.
* Support for optional inputs and outputs in automatically generated wrapper functions.
* Handwritten wrapper functions still supported (and will remain supported for the foreseeable future).

# 2.0: Aug. 2026
* Wire-encoding for data types plain JSON can't handle.
* Metrics & Observability
* Integration with MPS discovery API
* MCP Resources fully supported.
* build() method supports additional files.
* AI agent skills for tool building and deployment.

--- Copyright 2025-2026 The MathWorks, Inc. ---
