# Home Assistant Production Access Credentials

## Production Server Details
- **Home Assistant URL**: http://192.168.1.155:8123
- **SSH Access**: `ssh homeassistant` (configured key-based auth)
- **Config Directory**: `/config/` (maps to local `/home/dev/workspace/home-assistant-config/`)

## Long-Lived Access Token
**Current Token**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI5YTAyYzMxZTNkYjM0YmQxYTQ2YzNlMmJhZDExMjI3NCIsImlhdCI6MTc0NzUwODk4OSwiZXhwIjoyMDYyODY4OTg5fQ.BwOQMlSgBOi7kb2IwgSIK4KCRDe2mI-sJL496NUwHkE`

**Usage**: 
```bash
HA_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI5YTAyYzMxZTNkYjM0YmQxYTQ2YzNlMmJhZDExMjI3NCIsImlhdCI6MTc0NzUwODk4OSwiZXhwIjoyMDYyODY4OTg5fQ.BwOQMlSgBOi7kb2IwgSIK4KCRDe2mI-sJL496NUwHkE"
curl -H "Authorization: Bearer $HA_TOKEN" "http://192.168.1.155:8123/api/states/sensor.unavailable_entities"
```

## Token Details
- **Created**: September 24, 2025
- **Expiration**: 2062 (long-lived)
- **Issuer**: `9a02c31e3db34bd1a46c3e2bad112274`
- **Last Verified**: September 24, 2025 during entity cleanup operation

## Authentication Methods

### SSH Authentication
```bash
# Via SSH config entry 'homeassistant'
ssh homeassistant "ha core info"
ssh homeassistant "curl -H 'Authorization: Bearer $HA_TOKEN' 'http://192.168.1.155:8123/api/states'"
```

### Direct API Access
```bash
# From any system with network access
curl -H "Authorization: Bearer $HA_TOKEN" "http://192.168.1.155:8123/api/"
```

### Supervisor API Token (Alternative)
**Location**: `/etc/profile.d/homeassistant.sh`
**Current Value**: `d3cae221ab426c8f0721894a29aab34e9d938bcbfac196356405785687798e0a9a2d271108c13fc32ad31b0d0a9b9215bea4f8be6dff9783`

**Note**: Supervisor token is for local supervisor operations, not direct Home Assistant API access.

## Common API Endpoints

### System Health Monitoring
```bash
# Get unavailable entity count
curl -H "Authorization: Bearer $HA_TOKEN" "http://192.168.1.155:8123/api/states/sensor.unavailable_entities"

# Get detailed entity breakdown
curl -H "Authorization: Bearer $HA_TOKEN" "http://192.168.1.155:8123/api/states/sensor.unavailable_entities_details"

# Get failed automations count
curl -H "Authorization: Bearer $HA_TOKEN" "http://192.168.1.155:8123/api/states/sensor.failed_automations"
```

### Service Calls
```bash
# Restart Home Assistant
curl -X POST -H "Authorization: Bearer $HA_TOKEN" "http://192.168.1.155:8123/api/services/homeassistant/restart"

# Remove entity
curl -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id": "sensor.phantom_entity"}' \
  "http://192.168.1.155:8123/api/services/homeassistant/remove_entity"
```

## Security Notes
- Token provides full administrative access to Home Assistant
- Store securely and rotate if compromised
- Token persists through system reboots unlike some supervisor tokens
- Created via Home Assistant UI: Settings → Users → Long-Lived Access Tokens

## Troubleshooting
- **401 Unauthorized**: Token may have expired or been revoked
- **Token Changes**: Long-lived tokens should remain stable unless manually revoked
- **Network Issues**: Verify Home Assistant is accessible at 192.168.1.155:8123
- **SSH Issues**: Verify `homeassistant` SSH config entry is working

**Last Updated**: September 24, 2025
**Verified Working**: Entity cleanup operations, system health monitoring, service calls