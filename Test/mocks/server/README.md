# Mock HTTP Server for Testing

A configurable mock HTTP server that allows you to define routes and responses via JSON or YAML configuration files. Perfect for testing API clients, integration tests, or development when the real API isn't available.

## Features

- **Configuration-based**: Define all routes and responses in JSON or YAML files
- **Multiple HTTP methods**: Support for GET, POST, PUT, DELETE, PATCH
- **Flexible responses**: Configure status codes, headers, and response bodies
- **Regex path matching**: Use regular expressions for dynamic route matching
- **Response delays**: Simulate slow endpoints for timeout testing
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

### JSON Configuration

```json
{
  "routes": [
    {
      "path": "/api/endpoint",
      "methods": ["GET", "POST"],
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
```

### YAML Configuration

```yaml
routes:
  - path: /api/endpoint
    methods:
      - GET
      - POST
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
- **response** (object, required): Response configuration

### Response Object

- **status** (integer, optional): HTTP status code (default: 200)
- **headers** (object, optional): Response headers as key-value pairs
- **body** (string or object, optional): Response body. Objects are automatically JSON-stringified
- **delay** (number, optional): Delay in seconds before sending response (default: 0)

## Examples

### Example 1: Basic REST API

```json
{
  "routes": [
    {
      "path": "/api/users",
      "methods": ["GET"],
      "response": {
        "status": 200,
        "body": [
          {"id": 1, "name": "Alice"},
          {"id": 2, "name": "Bob"}
        ]
      }
    },
    {
      "path": "/api/users",
      "methods": ["POST"],
      "response": {
        "status": 201,
        "body": {"id": 3, "message": "Created"}
      }
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
    response:
      status: 200
      body:
        id: 1
        name: User Name
```

### Example 3: Error Responses

```json
{
  "routes": [
    {
      "path": "/api/error",
      "methods": ["GET"],
      "response": {
        "status": 500,
        "body": {
          "error": "Internal Server Error"
        }
      }
    },
    {
      "path": "/api/unauthorized",
      "methods": ["GET"],
      "response": {
        "status": 401,
        "body": {
          "error": "Unauthorized"
        }
      }
    }
  ]
}
```

### Example 4: Simulating Slow Responses

```yaml
routes:
  - path: /api/slow
    methods:
      - GET
    response:
      status: 200
      body:
        message: This took 3 seconds
      delay: 3
```

### Example 5: Custom Headers

```json
{
  "routes": [
    {
      "path": "/api/resource",
      "methods": ["POST"],
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
```

## Testing Your Configuration

Once the server is running, you can test it with curl:

```bash
# Test a GET endpoint
curl http://localhost:8080/api/users

# Test a POST endpoint
curl -X POST http://localhost:8080/api/users -d '{"name":"Charlie"}'

# Test with headers
curl -H "Authorization: Bearer token" http://localhost:8080/api/data
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
- Request body and query parameters are not used to vary responses
- No state management between requests
- No HTTPS support (HTTP only)

## License

Free to use and modify for your testing needs.

--- Copyright 2025-2026 The MathWorks, Inc. ---
