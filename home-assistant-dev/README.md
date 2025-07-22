# 🏠 Home Assistant Development Environment

A Docker-based development environment for testing Home Assistant configurations safely, separate from your production instance.

## 🚀 Quick Start

```bash
# Start the development environment
./scripts/start-dev.sh

# Access Home Assistant at: http://localhost:8124
```

## 📁 Directory Structure

```
home-assistant-dev/
├── config/                 # Home Assistant configuration files
├── data/                   # Container data volume
├── logs/                   # Development logs
├── scripts/                # Helper scripts
├── backups/                # Configuration backups
├── docker-compose.yml      # Docker configuration
└── README.md              # This file
```

## 🛠️ Available Scripts

### Core Operations
- `./scripts/start-dev.sh` - Start the development environment
- `./scripts/stop-dev.sh` - Stop the development environment  
- `./scripts/restart-dev.sh` - Restart the development environment

### Monitoring & Debugging
- `./scripts/logs-dev.sh` - View container logs
- `./scripts/logs-dev.sh -f` - Follow logs in real-time
- `./scripts/shell-dev.sh` - Get shell access to container

### Configuration Management
- `./scripts/sync-from-production.sh` - Sync config from production

## 🔧 Advanced Usage

### Start with Options
```bash
# Start and follow logs
./scripts/start-dev.sh --logs

# Clean start (remove existing data)
./scripts/start-dev.sh --clean

# Force rebuild container
./scripts/start-dev.sh --rebuild
```

### Configuration Testing
The development environment runs on port **8124** to avoid conflicts with production (port 8123).

**Development URL**: http://localhost:8124  
**Production URL**: http://192.168.1.155:8123

### Safe Development Practices

1. **Isolated Environment**: Changes don't affect production
2. **Development Secrets**: Uses safe placeholder values
3. **No Hardware Access**: USB devices disabled by default
4. **Clean Database**: Starts fresh without production data

## 🔄 Workflow

### 1. Sync from Production
```bash
./scripts/sync-from-production.sh
```

### 2. Make Changes
Edit configuration files in `./config/`

### 3. Test Changes
```bash
./scripts/restart-dev.sh
./scripts/logs-dev.sh -f
```

### 4. Validate Configuration
- Check logs for errors
- Test functionality in web UI
- Verify adaptive lighting works

### 5. Deploy to Production
Once validated, deploy changes to production server.

## 🎛️ Adaptive Lighting Development

This environment includes your complete **Phase 4 Adaptive Lighting** system:

- ✅ 14 configured zones
- ✅ Master control center
- ✅ Double-click controls
- ✅ Visual feedback system
- ✅ Auto-restore timers

**Note**: Some features may be limited without hardware devices:
- Z-Wave lights won't respond (no USB stick)
- Network device discovery may be limited
- Bluetooth devices won't be accessible

## 🐳 Docker Configuration

The environment uses:
- **Image**: `homeassistant/home-assistant:latest`
- **Port**: 8124 (mapped to container 8123)
- **Volumes**: Config mounted read-write for development
- **Network**: Bridge mode (isolated from production)

### Container Resources
- **Memory**: No limit (uses Docker default)
- **CPU**: No limit (uses Docker default)
- **Storage**: Local Docker volumes

## 🔐 Security Notes

- **Development Secrets**: Contains only placeholder values
- **No Production Data**: Database starts fresh each time
- **Isolated Network**: Cannot interfere with production
- **Safe Credentials**: Invalid tokens prevent accidental production access

## 🚨 Troubleshooting

### Container Won't Start
```bash
# Check container status
docker-compose ps

# View detailed logs
docker-compose logs

# Try clean restart
./scripts/start-dev.sh --clean
```

### Configuration Errors
```bash
# Check Home Assistant logs
./scripts/logs-dev.sh -f

# Access container for debugging
./scripts/shell-dev.sh

# Check configuration syntax
docker-compose exec homeassistant-dev hass --script check_config
```

### Port Conflicts
If port 8124 is in use:
1. Edit `docker-compose.yml`
2. Change `"8124:8123"` to `"8125:8123"` (or another port)
3. Update README and scripts accordingly

### Performance Issues
```bash
# Monitor container resources
docker stats hass-dev

# Check available disk space
df -h

# Clean up old containers/images
docker system prune
```

## 📊 Monitoring

### Health Checks
The container includes automatic health monitoring:
- **Check Interval**: 30 seconds
- **Timeout**: 10 seconds  
- **Retries**: 3 attempts
- **Start Period**: 60 seconds

### Log Management
- **Container Logs**: `docker-compose logs`
- **Home Assistant Logs**: Available in web UI and container
- **Rotation**: Handled by Docker log drivers

## 🔄 Updates

### Update Home Assistant Version
```bash
# Pull latest image
docker-compose pull

# Restart with new image
./scripts/start-dev.sh --rebuild
```

### Update Configuration
```bash
# Sync latest changes from production
./scripts/sync-from-production.sh

# Restart to apply changes
./scripts/restart-dev.sh
```

## 📞 Support

### Common Issues
1. **Config validation errors**: Check YAML syntax
2. **Missing integrations**: Some may not work without hardware
3. **Database errors**: Try `--clean` restart
4. **Network timeouts**: Check Docker networking

### Useful Commands
```bash
# Validate configuration without restart
docker-compose exec homeassistant-dev hass --script check_config

# Watch real-time logs
./scripts/logs-dev.sh -f

# Emergency stop
docker-compose kill

# Complete cleanup
docker-compose down -v --remove-orphans
```

---

**Environment**: Development Only  
**Production**: 192.168.1.155:8123  
**Created**: July 2, 2025  
**Version**: 1.0