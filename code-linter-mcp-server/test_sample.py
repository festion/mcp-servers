# Test Python code for Code Linter MCP Server
def hello_world():
    print("Hello, world!")
    x=1+2  # Missing spaces around operators (flake8 will catch this)
    return x

# Missing newline at end of file (another linting issue)
