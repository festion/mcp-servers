# AprilBrother BLE Gateway Suite - Tech Stack

## Core Technologies

### Programming Languages
- **Python 3.x**: Primary language for both custom component and add-on
- **YAML**: Configuration files, dashboards, and Home Assistant entity definitions
- **JSON**: Manifest files, configuration schemas, and data exchange
- **Bash**: Container scripts and utilities

### Home Assistant Integration
- **Custom Component Framework**: Home Assistant integration architecture
- **Config Flow**: UI-based configuration setup (`config_flow.py`)
- **Services**: Custom HA services for reconnection and cleanup
- **MQTT Integration**: Dependency on HA's MQTT component
- **Bluetooth Integration**: Dependency on HA's Bluetooth component

### Add-on Development
- **Home Assistant Add-on Architecture**: Supervisor-based containerized application
- **Docker**: Container packaging (`Dockerfile`)
- **Supervisor API**: Communication with Home Assistant core via REST API
- **Panel Integration**: Custom dashboard accessible from HA sidebar

### Communication Protocols
- **MQTT**: Primary protocol for BLE gateway data forwarding
- **SSDP**: Service discovery for automatic gateway detection (`_xbg._tcp.local.`)
- **REST API**: Home Assistant API communication
- **Bluetooth LE**: Target protocol for device communication

### Dependencies

#### Custom Component Requirements
- `msgpack==1.0.4`: Binary serialization for efficient data handling
- `homeassistant`: Development dependency for testing

#### Add-on Dependencies  
- `requests`: HTTP client for HA API communication
- Standard Python libraries: `json`, `logging`, `datetime`, `uuid`, `subprocess`

### Development Tools
- **Black**: Code formatting (line length: 88 characters)
- **Flake8**: Code linting and style checking
- **isort**: Import statement organization
- **pytest**: Unit testing framework

### Data Formats
- **MQTT Payloads**: JSON format from AprilBrother Gateway
  ```json
  {
    "v":1,"mid":12,"time":1744564900,
    "ip":"192.168.1.82","mac":"E831CDCCCBB0",
    "devices":[[0,"D712ED6A66C6",-85,"adv_data"]],
    "rssi":-43,"metadata":{...}
  }
  ```
- **Home Assistant Entities**: Standard HA entity state/attribute format
- **Discovery Data**: JSON structure for persistent device storage

### Container Technology
- **Docker**: Multi-architecture support (armhf, armv7, aarch64, amd64, i386)
- **Home Assistant Supervisor**: Add-on lifecycle management
- **Volume Mapping**: `/config` directory for persistent storage

### Testing Infrastructure
- **pytest**: Unit test execution with coverage reporting
- **Test Files**: `test_ble_discovery.py`, `tests/` directory
- **CI/CD**: GitHub Actions for automated testing (implied by .github structure)

### Version Control
- **Git**: Repository management
- **GitHub**: Remote repository hosting
- **Semantic Versioning**: Component and add-on versioning (e.g., v0.3.34, v1.7.6)