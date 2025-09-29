# AprilBrother BLE Gateway Suite - Project Structure

## Repository Organization

The repository serves dual purposes as both a HACS custom repository and a Home Assistant add-on repository.

### Root Level Structure
```
hass-ab-ble-gateway-suite/
├── custom_components/           # HACS Custom Component
├── enhanced_ble_discovery/      # HA Add-on (production)
├── addon/                       # Add-on development files
├── scripts/                     # Utility scripts
├── tests/                       # Unit tests
├── .github/                     # GitHub configuration
├── *.yaml                       # Dashboard configurations
├── *.md                         # Documentation
├── *.json                       # Repository configurations
└── requirements*.txt            # Python dependencies
```

## Custom Component (`custom_components/ab_ble_gateway/`)

### Core Files
- **`__init__.py`**: Component initialization, MQTT setup, services
- **`config_flow.py`**: UI-based configuration flow
- **`scanner.py`**: BLE gateway scanner implementation  
- **`const.py`**: Constants and configuration values
- **`util.py`**: Utility functions
- **`manifest.json`**: Component metadata and dependencies

### Configuration Files
- **`services.yaml`**: Service definitions (reconnect, clean_failed_entries)
- **`strings.json`**: UI text and translations
- **`translations/`**: Localization files
- **`scripts.yaml`**: Helper scripts for device management

### Dashboard Components
- **`ble_dashboard_snippets.yaml`**: Reusable dashboard code blocks
- **`ble_input_text.yaml`**: Input helper definitions

## Enhanced BLE Discovery Add-on (`enhanced_ble_discovery/`)

### Main Files
- **`ble_discovery.py`**: Main add-on Python code (2600+ lines)
- **`config.json`**: Add-on configuration and schema
- **`Dockerfile`**: Container build instructions
- **`README.md`**: Add-on specific documentation

### Container Structure
- **`rootfs/`**: Container filesystem
  - **`ble_discovery.py`**: Discovery script
  - **`run.sh`**: Container entry point
- **`run.sh`**: Local testing script

### Dashboard Files
- **`btle_combined_dashboard.yaml`**: Full-featured dashboard
- **`btle_dashboard.yaml`**: Basic discovery dashboard
- **`btle_gateway_management.yaml`**: Gateway status management
- **`scan_and_display_ble_devices.yaml`**: Device scanning interface
- **`test_ble_signal.yaml`**: Signal strength testing

### Configuration Helpers
- **`ble_input_text.yaml`**: Input text entity definitions
- **`ble_scripts.yaml`**: Automation scripts for device management

### Testing
- **`test_ble_discovery.py`**: Unit tests for add-on functionality

## Dashboard Collection (Root Level)

### Complexity Levels
- **`minimal_dashboard.yaml`**: Ultra-simple view for initial testing
- **`basic_dashboard.yaml`**: Simple status display for troubleshooting
- **`static_dashboard.yaml`**: Static view without dynamic updates
- **`atomic_dashboard.yaml`**: Atomic design principles
- **`verification_dashboard.yaml`**: Entity troubleshooting dashboard
- **`btle_ultra_simple.yaml`**: Minimal functionality
- **`btle_simple_dashboard.yaml`**: Streamlined interface

### Specialized Dashboards
- **`btle_combined_dashboard.yaml`**: Main production dashboard
- **`enhance_ble_devices.yaml`**: Device enhancement tools

## Development Structure (`addon/`)

Contains development versions of add-on files for testing before deployment.

## Testing Infrastructure (`tests/`)

- Unit test files for component functionality
- Test configuration files
- Mock data for testing scenarios

## Utility Scripts (`scripts/`)

- **`analyze_structure.py`**: Repository structure analysis
- Development and maintenance utilities

## Configuration Files

### Repository Configuration
- **`repository.json`**: HA add-on repository definition
- **`hacs.json`**: HACS custom repository configuration
- **`info.md`**: HACS repository information

### Development Configuration
- **`setup.cfg`**: Flake8 and isort configuration
- **`pytest.ini`**: Test runner configuration
- **`requirements*.txt`**: Python dependency specifications

### GitHub Configuration (`.github/`)
- **`CODEOWNERS`**: Code ownership definitions
- **`dependabot.yml`**: Dependency update automation
- **`ISSUE_TEMPLATE/`**: Issue templates for bug reports and features

## Documentation Structure

### Main Documentation
- **`README.md`**: Primary project documentation and installation guide
- **`CLAUDE.md`**: Comprehensive development and troubleshooting guide
- **`STRUCTURE.md`**: Detailed project structure documentation
- **`setup_instructions.md`**: Step-by-step setup guide

### Component Documentation
- **`LICENSE`**: Project license
- **`CODEOWNERS`**: File ownership for review purposes

## Key File Relationships

### Version Synchronization
- `custom_components/ab_ble_gateway/manifest.json` version
- `enhanced_ble_discovery/config.json` version
- Must be updated together for compatibility

### Configuration Dependencies
- Component depends on MQTT and Bluetooth integrations
- Add-on requires Supervisor API access
- Dashboards reference entities created by both component and add-on

### Development Workflow
- Develop in `addon/` directory
- Copy stable changes to `enhanced_ble_discovery/`
- Test component changes in development HA instance
- Validate dashboards with different entity availability states

## Data Flow Architecture

### MQTT Message Processing
1. AprilBrother Gateway → MQTT Broker
2. HA MQTT Integration → Custom Component
3. Custom Component → HA Bluetooth Integration
4. Add-on → HA API → Entity Updates

### Dashboard Data Sources
- Custom component entities (gateway status, device data)
- Add-on created entities (discovery results, management)
- Standard HA entities (input helpers, sensors)
- MQTT sensor entities (raw gateway data)

### Service Communication
- Component services: reconnect, clean_failed_entries
- Add-on API calls: entity creation, state updates, notifications
- Dashboard scripts: device addition, signal testing