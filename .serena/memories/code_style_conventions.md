# AprilBrother BLE Gateway Suite - Code Style and Conventions

## Python Code Style

### Formatting and Linting
- **Black**: Code formatter with 88-character line length
- **Flake8**: Linting with specific ignore rules:
  - E501: line too long (handled by Black)
  - W503: line break before binary operator
  - E203: whitespace before ':'
  - D202: no blank lines after function docstring
  - W504: line break after binary operator
- **isort**: Import sorting with specific configuration

### Import Organization (isort config)
```python
# Standard library imports
import json
import logging
import datetime

# Third-party imports  
import requests

# Home Assistant imports
from homeassistant.core import HomeAssistant
from homeassistant.config_entries import ConfigEntry

# Local imports
from .const import DOMAIN
```

### Naming Conventions
- **Variables/Functions**: `snake_case`
  - `setup_logging()`, `device_mac`, `gateway_devices`
- **Classes**: `PascalCase`
  - `BLEGatewayScanner`, `ConfigFlow`
- **Constants**: `UPPER_SNAKE_CASE`
  - `DOMAIN`, `DEFAULT_SCAN_INTERVAL`, `SERVICE_RECONNECT`
- **Private methods**: Leading underscore
  - `_async_on_advertisement()`, `_process_mqtt_message()`

### Type Hints
- **Required**: Function parameters and return values
- **Format**: Standard Python typing module
```python
def process_ble_gateway_data(gateway_devices: list) -> list[dict]:
    """Process raw BLE gateway data into structured format."""
    pass
```

### Error Handling
- **Specific Exceptions**: Use specific exception types rather than bare `except:`
- **Logging**: Always log errors with context
- **Continue on Error**: Use `continue_on_error: true` in service calls where appropriate
```python
try:
    response = requests.get(url, headers=headers)
    if response.status_code >= 300:
        logging.error(f"API error: {response.status_code} - {response.text}")
        return False
except requests.exceptions.RequestException as e:
    logging.error(f"Request failed: {e}")
    return False
```

### String Formatting
- **f-strings**: Preferred for string interpolation
- **Multi-line**: Use triple quotes for long strings
```python
message = f"Found {len(devices)} devices with RSSI > {threshold}"
notification = f"""
    Discovery complete:
    - Total devices: {total}
    - New devices: {new_count}
"""
```

### Docstrings
- **Google style**: Brief description followed by Args/Returns
```python
def discover_ble_devices(force_scan: bool = False) -> list[dict]:
    """
    Discover BLE devices using the BLE gateway.
    
    Args:
        force_scan: Whether to trigger a fresh scan before discovery
        
    Returns:
        List of discovered device dictionaries
    """
```

## YAML Style

### Home Assistant Configuration
- **2-space indentation**: Standard HA convention
- **Descriptive names**: Clear entity IDs and friendly names
- **Comments**: Document complex logic and purposes
```yaml
# BLE Device Discovery Input Helpers
input_text:
  discovered_ble_devices:
    name: "Discovered BLE Devices"
    max: 1024
    initial: "{}"
    icon: mdi:bluetooth-search
```

### Service Definitions
- **Clear descriptions**: Explain purpose and usage
- **Proper schemas**: Define parameter types and validation
```yaml
services:
  reconnect:
    name: "Reconnect MQTT"
    description: "Reconnect to MQTT broker and refresh device list"
    fields:
      dry_run:
        description: "Preview changes without executing"
        example: false
        default: false
        selector:
          boolean:
```

## File Organization

### Directory Structure
- **Logical grouping**: Related files in appropriate directories
- **Clear naming**: Descriptive file and directory names
- **Separation of concerns**: Component vs add-on code separation

### File Naming
- **Python modules**: `snake_case.py`
- **YAML configs**: `descriptive_name.yaml`
- **Documentation**: `UPPER_CASE.md` for main docs, `snake_case.md` for specific docs

### Imports
- **Absolute imports**: Prefer absolute over relative imports
- **Minimal imports**: Only import what's needed
- **Grouped logically**: Standard library, third-party, local imports

## Documentation Standards

### README Structure
- **Clear purpose**: What the project does
- **Installation steps**: Step-by-step setup instructions
- **Feature list**: Key capabilities and benefits
- **Support information**: How to get help

### Code Comments
- **Why, not what**: Explain reasoning, not obvious actions
- **Complex logic**: Document non-obvious algorithms
- **TODOs**: Mark future improvements clearly
```python
# Use adaptive interval based on activity level to reduce battery usage
# while maintaining responsiveness for active periods
adaptive_interval = determine_adaptive_scan_interval(base_interval, devices, activity)
```

### Version Control
- **Semantic versioning**: MAJOR.MINOR.PATCH format
- **Synchronized versions**: Component and add-on versions should align
- **Change documentation**: Update CLAUDE.md with version-specific changes

## Testing Conventions

### Test Structure
- **Test file naming**: `test_*.py`
- **Test method naming**: `test_specific_functionality`
- **Arrange-Act-Assert**: Clear test structure
```python
def test_process_ble_gateway_data():
    # Arrange
    mock_data = [["device1", "AA:BB:CC:DD:EE:FF", -65, "adv_data"]]
    
    # Act
    result = process_ble_gateway_data(mock_data)
    
    # Assert
    assert len(result) == 1
    assert result[0]["mac_address"] == "AA:BB:CC:DD:EE:FF"
```

### Mocking
- **External dependencies**: Mock API calls, file system operations
- **Isolation**: Each test should be independent
- **Realistic data**: Use realistic test data that matches production formats