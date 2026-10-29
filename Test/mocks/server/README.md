# Mock HTTP Server for Testing

A configurable mock HTTP server that answers requests as a JSON or YAML configuration file describes. The client integration tests (`Test/integration/client`, via `MockCaller`) use it to stand in for an MCP server or MATLAB Production Server.

## Features

- **Configuration-based**: Define all routes and responses in JSON or YAML files
- **Multiple HTTP methods**: Support for GET, POST, PUT, DELETE, PATCH
- **Request matching**: Choose the response by JSON-RPC method, tool arguments, request body or HTTP method
- **Flexible responses**: Configure status codes, headers, and response bodies
- **Regex path matching**: Use regular expressions for dynamic route matching
- **Response delays**: Simulate slow endpoints for timeout testing
- **Request counts**: `/stats` reports how many requests each route received
- **Easy to use**: Simple command-line interface

## Installation

Requires Python 3.6+ and PyYAML (for YAML config files):

```bash
pip install pyyaml
```

## Usage

### Basic Usage

```bash
python mock_server.py config.json
```

### Custom Host and Port

```bash
python mock_server.py config.yaml --host 0.0.0.0 --port 3000
```

### Command-line Options

- `config`: Path to configuration file (required)
- `--host`: Host to bind to (default: localhost)
- `--port`: Port to bind to (default: 8080)

## Configuration Format

A configuration is a list of routes. Each route lists the requests it answers, and each of those has the response to send.

### JSON Configuration

```json
{
  "routes": [
    {
      "path": "/api/endpoint",
      "methods": ["GET", "POST"],
      "request": [
        {
          "body": "",
          "response": {
            "status": 200,
            "headers": {
              "Content-Type": "application/json"
            },
            "body": {
              "message": "Success"
            }
          }
        }
      ]
    }
  ]
}
```

### YAML Configuration

```yaml
routes:
  - path: /api/endpoint
    methods:
      - GET
      - POST
    request:
      - body: ""
        response:
          status: 200
          headers:
            Content-Type: application/json
          body:
            message: Success
```

## Configuration Options

### Route Object

- **path** (string, required): The URL path to match
- **methods** (array, optional): HTTP methods to accept (default: ["GET"])
- **regex** (boolean, optional): If true, treat path as a regex pattern (default: false)
- **request** (array, required): Request entries; see below

The first route whose path and methods match a request answers it.

### Request Entries

The mock answers a request with the `response` of the first entry in its
route's `request` list that matches:

- **jrpc** (string): Matches a JSON request (`Content-Type: application/json`)
  whose JSON-RPC `method` is this value.
- **call** (object): With `jrpc: tools/call`, also requires `params.arguments`
  to equal `call.input`. Every `tools/call` entry must have one: without it,
  the mock fails the request and drops the connection.
- **body** (string): Matches any other request whose body is exactly this
  text. `""` matches an empty body, which is what a GET or DELETE sends.
- **method** (string, optional): Matches only requests with this HTTP method.
  Without it, the entry matches any method in the route's `methods`.
- **response** (object, required): The response to send.

A JSON request is matched only by `jrpc` entries, and any other request only
by `body` entries. The `Content-Type` must be exactly `application/json`: with
a parameter such as `; charset=utf-8`, the request is matched by its body text.

```yaml
routes:
  - path: /mcp
    methods:
      - POST
      - DELETE
    request:
      - jrpc: tools/list
        response:
          status: 200
          body:
            result:
              tools: []
      - method: DELETE
        body: ""
        response:
          status: 500
```

A request that matches no route, or no entry in its route, gets a 404.

### Response Object

- **status** (integer, optional): HTTP status code (default: 200)
- **headers** (object, optional): Response headers as key-value pairs
- **body** (string or object, optional): Response body. Objects are sent as JSON, with `Content-Type: application/json` unless `headers` sets it. A top-level array is not supported; wrap it in an object.
- **delay** (number, optional): Delay in seconds before sending response (default: 0)

### Built-in Routes

Two paths are answered whatever the configuration says. Both are for tests.

- **/stats**: A JSON object counting the requests received so far, keyed by
  `"METHOD path"`, for example `{"POST /mcp": 3}`. Requests to `/stats` and
  `/stop` are not counted. A test uses this to check whether the client
  retried.
- **/stop**: Answers 200, then shuts the server down.

## Examples

### Example 1: Basic REST API

```json
{
  "routes": [
    {
      "path": "/api/users",
      "methods": ["GET", "POST"],
      "request": [
        {
          "method": "GET",
          "body": "",
          "response": {
            "status": 200,
            "body": {
              "users": [
                {"id": 1, "name": "Alice"},
                {"id": 2, "name": "Bob"}
              ]
            }
          }
        },
        {
          "method": "POST",
          "body": "name=Charlie",
          "response": {
            "status": 201,
            "body": {"id": 3, "message": "Created"}
          }
        }
      ]
    }
  ]
}
```

### Example 2: Regex Path Matching

```yaml
routes:
  # Matches /api/users/1, /api/users/2, etc.
  - path: ^/api/users/\d+$
    regex: true
    methods:
      - GET
    request:
      - body: ""
        response:
          status: 200
          body:
            id: 1
            name: User Name
```

### Example 3: JSON-RPC Requests

```yaml
routes:
  - path: /mcp
    methods:
      - POST
    request:
      - jrpc: tools/call
        call:
          name: add
          input:
            a: 1
            b: 2
        response:
          status: 200
          body:
            result:
              structuredContent:
                sum: 3
```

The entry matches only when the arguments are exactly `{"a": 1, "b": 2}`; any other `tools/call` gets a 404. The `name` is not compared.

### Example 4: Error Responses

```json
{
  "routes": [
    {
      "path": "/api/error",
      "methods": ["GET"],
      "request": [
        {
          "body": "",
          "response": {
            "status": 500,
            "body": {
              "error": "Internal Server Error"
            }
          }
        }
      ]
    },
    {
      "path": "/api/unauthorized",
      "methods": ["GET"],
      "request": [
        {
          "body": "",
          "response": {
            "status": 401,
            "body": {
              "error": "Unauthorized"
            }
          }
        }
      ]
    }
  ]
}
```

### Example 5: Simulating Slow Responses

```yaml
routes:
  - path: /api/slow
    methods:
      - GET
    request:
      - body: ""
        response:
          status: 200
          body:
            message: This took 3 seconds
          delay: 3
```

### Example 6: Custom Headers

```json
{
  "routes": [
    {
      "path": "/api/resource",
      "methods": ["POST"],
      "request": [
        {
          "body": "create",
          "response": {
            "status": 201,
            "headers": {
              "Content-Type": "application/json",
              "Location": "/api/resource/123",
              "X-Custom-Header": "value"
            },
            "body": {
              "id": 123
            }
          }
        }
      ]
    }
  ]
}
```

## Testing Your Configuration

Once the server is running, you can test it with curl (these requests match Example 1):

```bash
# Test a GET endpoint
curl http://localhost:8080/api/users

# Test a POST endpoint; curl -d sends a form body, matched as text
curl -X POST http://localhost:8080/api/users -d 'name=Charlie'

# See how many requests each route has received
curl http://localhost:8080/stats
```

## Use Cases

- **API Client Testing**: Test your API client without needing the real backend
- **Integration Tests**: Create reproducible test scenarios
- **Frontend Development**: Develop UI features before the API is ready
- **Error Handling**: Test how your application handles various error responses
- **Performance Testing**: Simulate slow endpoints with response delays
- **CI/CD Pipelines**: Use in automated testing environments

## Tips

1. **Start Simple**: Begin with a basic config and add routes as needed
2. **Use Regex Sparingly**: Exact path matching is faster and easier to debug
3. **Organize Configs**: Create different config files for different test scenarios
4. **Log Monitoring**: Watch the console output to see which routes are being hit
5. **Status Codes**: Use appropriate HTTP status codes to test error handling

## Limitations

- No authentication/authorization logic (returns whatever is configured)
- Request headers (other than `Content-Type`) and query parameters are not used to vary responses
- No state management between requests, apart from the `/stats` counts
- Single-threaded: a delayed response holds up every request behind it
- No HTTPS support (HTTP only)

## License

Free to use and modify for your testing needs.

--- Copyright 2025-2026 The MathWorks, Inc. ---
