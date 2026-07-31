---
name: mps-mcp-build
description: Create and deploy MCP tools from MATLAB functions to MATLAB Production Server using the MCP Framework for MATLAB Production Server support package
argument-hint: <function path(s), server address, optional files/resources>
disable-model-invocation: true
allowed-tools: Read Bash(matlab *) Bash(which matlab) Bash(ls *) Bash(grep *) mcp__matlab__evaluate_matlab_code
---

# Create MCP Tool from MATLAB Function

You are helping the user create and deploy MCP tools from MATLAB functions to a MATLAB Production Server using the MCP Framework for MATLAB Production Server support package.

## Step 1: Check Prerequisites

Before doing anything else, verify these prerequisites are met:

1. **MATLAB availability**: Check if the MATLAB MCP Core Server is available as a configured MCP tool (the `evaluate_matlab_code` tool). If it is, use it for all MATLAB execution in subsequent steps. If not, check if MATLAB is accessible by running `which matlab` and fall back to `matlab -batch "..."` on the command line.
2. **MCP Framework availability**: This is verified automatically as part of the combined build call in Step 5. Do NOT run a separate call just to check for the support package.

If neither the MCP Core Server nor command-line MATLAB is available, report clearly what is needed and **stop**. Do NOT attempt to download, install, or otherwise acquire MATLAB or the support package.

### Using MCP Core Server vs. command-line MATLAB

Throughout this skill, MATLAB code is shown as `matlab -batch "..."` commands. If the `evaluate_matlab_code` tool is available, replace each `matlab -batch` call with a call to `evaluate_matlab_code`, passing the MATLAB code as the argument. The code content is identical — only the execution mechanism differs. When using `evaluate_matlab_code`:
- Do NOT wrap code in try/catch with section markers — the tool reports errors directly
- Do NOT use `fprintf` for output — use `disp()` or let expressions print naturally
- Do NOT call `exit(1)` — the tool handles error signaling

## Step 2: Parse User Intent

Extract the following from the user's request:

- **Function path(s)**: One or more paths to `.m` files (required)
- **Server address**: Host and port of the MATLAB Production Server (required), e.g. `localhost:9910`
- **Scheme**: `http` (default) or `https` if the user specifies it
- **Additional files**: Extra files to include in the CTF archive (optional)
- **Resources**: MCP resources to include (optional), specified in flexible formats such as:
  - `"add a resource at config://settings with the contents from settings.json"`
  - `"create the resource data://AuthorName with string value 'Mr. Author'"`
  - `"add the following resources: config://settings,settings.json, data://AuthorName,'Mr. Author'"`

For resources, construct a MATLAB struct array where each element has:
- `uri`: the resource URI (e.g. `"config://settings"`)
- `contents`: the resource contents — either a file path to read from or a literal string value

## Step 3: Validate File Paths (Case-Sensitive)

For **all** file paths provided by the user — including function `.m` files **and** any optional additional files — verify that each filename matches a file on disk **exactly**, including case. Windows filesystems are case-insensitive, so a path may resolve even when the case is wrong — but MATLAB function names are case-sensitive and must match the file exactly, and additional files must also be referenced by their exact on-disk name to avoid deployment issues.

For each path:

1. Check whether the path resolves at all:
   ```bash
   ls "<full_path>" &>/dev/null
   ```
2. If the path does not resolve, report an error: **"File not found: `<path>`"** and **stop**.
3. If the path resolves, verify the filename case by listing the parent directory and checking for an exact (case-sensitive) match:
   ```bash
   ls "<parent_dir>" | grep -x "<filename>"
   ```
4. If `grep -x` finds no match, the file exists with different case. Find the actual name:
   ```bash
   ls "<parent_dir>" | grep -ix "<filename>"
   ```
   Then ask the user: **"The file on disk is named `<actual_name>`, but you specified `<user_name>`. Would you like to use `<actual_name>` instead?"**
   Wait for the user to confirm before proceeding. If they decline, **stop**.
5. If `grep -x` succeeds, the case matches — proceed.

Only continue to Step 4 once all file paths have been validated.

## Step 4: Prepare Working Directory

Before building, copy the specified MATLAB function file(s) into the deployment folder. This avoids conflicts with pre-existing wrapper files (e.g., `<fcnName>MCP.m`) that may already exist in the source directory and would interfere with the framework's automatic wrapper generation.

1. Create the deployment folder if it does not exist.
2. **Delete any pre-existing MCP wrapper files** from the deployment folder. For each function `foo`, remove `fooMCP.m` if it exists. The wrapper name is case-sensitive: for function `foo` the wrapper is `fooMCP.m`, for `Foo` it is `FooMCP.m`. Remove only the exact match.
3. **Delete any existing copy of the function file** in the deployment folder before copying. On Windows (case-insensitive filesystem), `cp` will silently keep the case of an existing file rather than using the source's case. Always `rm -f <folder>/<filename>` first, then copy. This ensures the destination file has the exact case of the source.
4. Copy the specified `.m` function file(s) into the deployment folder.
5. Run the build from the deployment folder (use `cd` to set it as the working directory).

This ensures the framework generates fresh wrappers without conflicts from stale cached files.

## Step 5: Build and Deploy

Construct and execute a **single** `matlab -batch` call that combines the prerequisite check with the build and deploy. This avoids paying the MATLAB startup cost multiple times.

Arguments to `prodserver.mcp.build`:

- `fcn`: Function name(s) derived from the file path(s) (filename without `.m` extension)
- `server`: Full server URL as `"<scheme>://<host>:<port>"` (default scheme is `http`)
- `files`: String array of additional file paths (only if user specified them)
- `resource`: Struct array of resources (only if user specified them)
- `folder`: The deployment folder (same directory the function was copied into)

**Important:**
- Do NOT specify the `wrapper` argument — accept the framework's default behavior
- Do NOT read the MATLAB function or make any judgements about wrappers
- Always `cd` into the deployment folder before calling `build` so generated wrappers are co-located with the source function
- **All paths in `matlab -batch` scripts MUST be absolute paths** — after `cd` changes the working directory, relative paths will resolve incorrectly. This applies to the `cd` target, the `folder` argument, file paths, and any other path references.
- **Always `addpath` the project root** (the directory containing the `+prodserver` package folder) before `cd`-ing into the deployment folder. Without this, `cd` moves away from the package and MATLAB can no longer resolve `prodserver.mcp.*` functions.

### Combined script structure

The script uses section markers (`===STEP:name===`, `===OK:name===`, `===FAIL:name===`) so that you can parse the output and identify exactly which stage failed:

```matlab
matlab -batch "
addpath('<project-root>');
fprintf('===STEP:prerequisite===\n');
try
    help prodserver.mcp.build;
    fprintf('===OK:prerequisite===\n');
catch e
    fprintf('===FAIL:prerequisite===\n%s\n', e.message);
    exit(1);
end

fprintf('===STEP:build===\n');
try
    cd('<absolute-folder-path>');
    [ctf, endpoint] = prodserver.mcp.build('<fcnName>', server='<scheme>://<host>:<port>', folder='<absolute-folder-path>');
    fprintf('===OK:build===\n');
    fprintf('CTF: %s\nEndpoint: %s\n', ctf, endpoint);
catch e
    fprintf('===FAIL:build===\n%s\n', e.message);
    exit(1);
end
"
```

Where `<project-root>` is the absolute path to the directory containing the `+prodserver` package (i.e. the root of this repository), and `<absolute-folder-path>` is the absolute path to the deployment folder.

### Output parsing

After the command completes, parse the output:

- If `===FAIL:prerequisite===` is present → the MCP Framework support package is not installed or not on the path. Report this to the user and **stop**.
- If `===OK:prerequisite===` is present but `===FAIL:build===` is present → the build failed. The error message follows the FAIL marker. Diagnose and report.
- If `===OK:build===` is present → extract the CTF path and endpoint URL from the lines following the OK marker.

### Build success criteria

The build is successful only when **both** of the following are true:

1. **No errors**: The `matlab -batch` command exits with code 0 and output contains `===OK:build===`.
2. **CTF is newer than wrapper**: The generated `.ctf` archive must have a modification timestamp strictly later than the generated MCP wrapper file (`<fcnName>MCP.m`). If the wrapper exists but the CTF is older or missing, the build did not complete — a stale CTF from a previous build is not acceptable.

If either criterion fails, diagnose and retry the build (e.g., delete stale artifacts and rebuild from scratch).

If the build succeeds but the deploy step within `build` fails (e.g., cannot find the archive), deploy separately using `prodserver.mcp.deploy` with the full path to the generated `.ctf` file. Include this as a second try/catch block appended to the script:
```matlab
fprintf('===STEP:deploy===\n');
try
    endpoint = prodserver.mcp.deploy('<absolute-folder-path>/<fcnName>.ctf', '<host>', <port>, scheme='<scheme>');
    fprintf('===OK:deploy===\n');
    fprintf('Endpoint: %s\n', endpoint);
catch e
    fprintf('===FAIL:deploy===\n%s\n', e.message);
    exit(1);
end
```

### Example MATLAB commands:

In all examples below, `<project-root>` is the absolute path to the directory containing the `+prodserver` package, and `<folder>` is the absolute path to the deployment folder.

Single function, no extras:
```matlab
matlab -batch "addpath('<project-root>'); fprintf('===STEP:prerequisite===\n'); try, help prodserver.mcp.build; fprintf('===OK:prerequisite===\n'); catch e, fprintf('===FAIL:prerequisite===\n%s\n', e.message); exit(1); end; fprintf('===STEP:build===\n'); try, cd('<folder>'); [ctf, endpoint] = prodserver.mcp.build('fcnName', server='http://localhost:9910', folder='<folder>'); fprintf('===OK:build===\n'); fprintf('CTF: %s\nEndpoint: %s\n', ctf, endpoint); catch e, fprintf('===FAIL:build===\n%s\n', e.message); exit(1); end"
```

With additional files:
```matlab
matlab -batch "addpath('<project-root>'); fprintf('===STEP:prerequisite===\n'); try, help prodserver.mcp.build; fprintf('===OK:prerequisite===\n'); catch e, fprintf('===FAIL:prerequisite===\n%s\n', e.message); exit(1); end; fprintf('===STEP:build===\n'); try, cd('<folder>'); [ctf, endpoint] = prodserver.mcp.build('fcnName', server='http://localhost:9910', folder='<folder>', files=[""data.mat"", ""config.json""]); fprintf('===OK:build===\n'); fprintf('CTF: %s\nEndpoint: %s\n', ctf, endpoint); catch e, fprintf('===FAIL:build===\n%s\n', e.message); exit(1); end"
```

With resources:
```matlab
matlab -batch "addpath('<project-root>'); fprintf('===STEP:prerequisite===\n'); try, help prodserver.mcp.build; fprintf('===OK:prerequisite===\n'); catch e, fprintf('===FAIL:prerequisite===\n%s\n', e.message); exit(1); end; fprintf('===STEP:build===\n'); try, cd('<folder>'); r(1).uri='config://settings'; r(1).contents='settings.json'; [ctf, endpoint] = prodserver.mcp.build('fcnName', server='http://localhost:9910', folder='<folder>', resource=r); fprintf('===OK:build===\n'); fprintf('CTF: %s\nEndpoint: %s\n', ctf, endpoint); catch e, fprintf('===FAIL:build===\n%s\n', e.message); exit(1); end"
```

Multiple functions:
```matlab
matlab -batch "addpath('<project-root>'); fprintf('===STEP:prerequisite===\n'); try, help prodserver.mcp.build; fprintf('===OK:prerequisite===\n'); catch e, fprintf('===FAIL:prerequisite===\n%s\n', e.message); exit(1); end; fprintf('===STEP:build===\n'); try, cd('<folder>'); [ctf, endpoint] = prodserver.mcp.build([""fcn1"", ""fcn2""], server='http://localhost:9910', folder='<folder>'); fprintf('===OK:build===\n'); fprintf('CTF: %s\nEndpoint: %s\n', ctf, endpoint); catch e, fprintf('===FAIL:build===\n%s\n', e.message); exit(1); end"
```

## Step 6: Verify Deployment

After a successful build and deploy, verify the deployment using a **single** `matlab -batch` call that combines ping and list. Use a **2-minute timeout** for verification. Only use a longer timeout if the user explicitly requests one.

```matlab
matlab -batch "
addpath('<project-root>');
fprintf('===STEP:ping===\n');
try
    ok = prodserver.mcp.ping('<scheme>://<host>:<port>/<archiveName>/mcp');
    if ~ok, error('prodserver:mcp:pingFailed', 'Ping returned false'); end
    fprintf('===OK:ping===\n');
catch e
    fprintf('===FAIL:ping===\n%s\n', e.message);
    exit(1);
end

fprintf('===STEP:list===\n');
try
    tools = prodserver.mcp.list('<scheme>://<host>:<port>/<archiveName>/mcp', 'Tool');
    for i=1:numel(tools)
        fprintf('%s - %s\n', tools{i}.name, tools{i}.description);
    end
    fprintf('===OK:list===\n');
catch e
    fprintf('===FAIL:list===\n%s\n', e.message);
    exit(1);
end
"
```

Where `<project-root>` is the same absolute path used in Step 5.

### Output parsing

- If `===FAIL:ping===` is present → the server is not responding. Retry once after 10 seconds (re-run the entire combined verification call). If it still fails, **stop immediately** — do NOT continue to Step 7 or Step 8.
- If `===OK:ping===` is present but `===FAIL:list===` is present → the archive loaded but tools couldn't be enumerated. Report the error message.
- If `===OK:list===` is present → extract tool names and descriptions from the lines between `===OK:ping===` and `===OK:list===`.

### On failure

If verification fails after the retry, report an error to the user explaining that the MCP server is not responding, provide the endpoint URL, and suggest they check that:
- The MATLAB Production Server is running
- The archive was loaded successfully (check MPS logs)
- The server address and port are correct

## Step 7: Register MCP Server in Claude Code

After successful deployment verification, register the new MCP server so the tool is available to Claude.

By default, register at **user scope** in `~/.claude.json`. If the user explicitly requests project-level registration, use `.mcp.json` in the project root instead.

Add an entry using the deployed endpoint URL. The server name should be the archive name (typically the function name for single-tool deployments).

### User scope (default): `~/.claude.json`

Read `~/.claude.json`. If it does not exist, create it. If it already has an `mcpServers` object, add the new entry to it. If not, create the `mcpServers` key. The format is:

```json
{
  "mcpServers": {
    "<serverName>": {
      "type": "http",
      "url": "<scheme>://<host>:<port>/<archiveName>/mcp"
    }
  }
}
```

For example, after deploying `cleanSignal` to `http://localhost:9910`:
```json
{
  "mcpServers": {
    "cleanSignal": {
      "type": "http",
      "url": "http://localhost:9910/cleanSignal/mcp"
    }
  }
}
```

### Project scope: `.mcp.json`

If the user requests project-level registration, read `.mcp.json` in the project root. If it does not exist, create it. Add the server entry under the `mcpServers` key using the same format as above.

## Step 8: Report Results

Report to the user:
- The endpoint URL
- The tool name(s) and description(s) deployed
- That the MCP server has been registered in Claude Code settings
- **Inform the user that they must restart Claude Code (or start a new session) for the new MCP tool to become available**

--- Copyright 2026 The MathWorks, Inc. ---
