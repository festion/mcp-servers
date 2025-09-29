# AprilBrother BLE Gateway Suite - Suggested Commands

## Development Commands

### Code Quality and Formatting
```bash
# Format Python code with Black
black custom_components/
black enhanced_ble_discovery/

# Check code style with Flake8  
flake8 custom_components/
flake8 enhanced_ble_discovery/ble_discovery.py

# Sort imports with isort
isort custom_components/
isort enhanced_ble_discovery/

# Run all formatting and linting together
black custom_components/ enhanced_ble_discovery/ && \
flake8 custom_components/ enhanced_ble_discovery/ble_discovery.py && \
isort custom_components/ enhanced_ble_discovery/
```

### Testing
```bash
# Run unit tests with coverage
pytest tests/

# Run specific test file
pytest tests/test_ble_discovery.py

# Run tests with verbose output
pytest tests/ -v

# Run tests with coverage report
pytest tests/ --cov=custom_components
```

### Development Testing

#### Custom Component Testing
```bash
# Install component in development Home Assistant
cp -r custom_components/ab_ble_gateway /path/to/homeassistant/custom_components/

# Check Home Assistant configuration
ha core check

# Restart Home Assistant
ha core restart

# View Home Assistant logs
ha core logs
```

#### Add-on Development
```bash
# Build Docker image locally
docker build -t ble-discovery-addon ./enhanced_ble_discovery

# Run add-on locally for testing
./enhanced_ble_discovery/run.sh

# Run add-on with custom parameters
cd enhanced_ble_discovery && \
python3 ble_discovery.py --log-level DEBUG --scan-interval 30

# View add-on logs
docker logs ble-discovery-addon
```

### File Operations
```bash
# Find Python files
find . -name "*.py" -type f

# Find YAML files
find . -name "*.yaml" -type f

# Search for specific patterns in code
grep -r "bluetooth" custom_components/
grep -r "mqtt" enhanced_ble_discovery/

# Check file permissions
ls -la enhanced_ble_discovery/run.sh

# Make script executable
chmod +x enhanced_ble_discovery/run.sh
```

### Git Operations
```bash
# Check repository status
git status

# View recent commits
git log --oneline -10

# Create feature branch
git checkout -b feature/new-functionality

# Stage and commit changes
git add .
git commit -m "feat: add new BLE device categorization"

# Push changes
git push origin feature/new-functionality
```

### Project Analysis
```bash
# Analyze project structure
python3 scripts/analyze_structure.py

# Check for TODO items
grep -r "TODO" . --include="*.py" --include="*.yaml"

# Find large files
find . -type f -size +100k -exec ls -lh {} \;

# Count lines of code
find . -name "*.py" -exec wc -l {} + | tail -1
```

### Debugging and Diagnostics
```bash
# Check MQTT connectivity (if mosquitto-clients installed)
mosquitto_sub -h localhost -t "xbg" -v

# Test Home Assistant API connectivity
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8123/api/states

# Check Docker container status
docker ps | grep ble

# View container logs
docker logs -f ble-discovery-addon

# Check system Bluetooth status
bluetoothctl show
hciconfig
```

### Release Commands
```bash
# Update version in manifest.json
jq '.version = "0.3.35"' custom_components/ab_ble_gateway/manifest.json > tmp.json && \
mv tmp.json custom_components/ab_ble_gateway/manifest.json

# Update version in add-on config.json
jq '.version = "1.7.7"' enhanced_ble_discovery/config.json > tmp.json && \
mv tmp.json enhanced_ble_discovery/config.json

# Create git tag
git tag -a v0.3.35 -m "Release version 0.3.35"
git push origin v0.3.35

# Build production Docker image
docker build -t ghcr.io/festion/ble-discovery:1.7.7 ./enhanced_ble_discovery
```

### Maintenance Commands
```bash
# Clean up Python cache
find . -type d -name "__pycache__" -exec rm -rf {} +
find . -name "*.pyc" -delete

# Clean up temporary files
rm -f *.tmp *.log
find . -name ".DS_Store" -delete

# Update dependencies
pip install --upgrade homeassistant
pip install --upgrade msgpack

# Check for security vulnerabilities
pip audit
```

### Directory Navigation
```bash
# Project root
cd /home/dev/workspace/hass-ab-ble-gateway-suite

# Custom component
cd custom_components/ab_ble_gateway

# Add-on code
cd enhanced_ble_discovery

# Documentation
cd docs

# Test files
cd tests
```

## Utility Commands for Linux Development Environment

### System Information
```bash
# Check system info
uname -a
lsb_release -a

# Check available disk space
df -h

# Check memory usage
free -h

# Check running processes
ps aux | grep python
```

### Network Debugging
```bash
# Check network connectivity
ping 192.168.1.82  # Example gateway IP

# Check open ports
netstat -tlnp
ss -tlnp

# Check MQTT broker
telnet localhost 1883
```

### Home Assistant Integration
```bash
# Check Home Assistant service status
systemctl status home-assistant@homeassistant

# View Home Assistant configuration directory
ls -la /config/

# Check custom components
ls -la /config/custom_components/

# View add-on logs
journalctl -u hassio-supervisor -f
```