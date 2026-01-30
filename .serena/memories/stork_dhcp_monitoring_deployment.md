# Stork DHCP Monitoring Deployment

## Summary
Successfully installed and configured ISC Stork v2.2.1 to monitor and manage Kea DHCP servers in HA configuration.

## Infrastructure

### Stork Server (LXC 135)
- **Hostname**: stork-server
- **IP Address**: 192.168.1.234 (DHCP)
- **Web UI**: http://192.168.1.234:8080
- **Version**: ISC Stork 2.2.1 (build 2025-08-28)
- **OS**: Debian GNU/Linux 12 (bookworm)
- **Service**: isc-stork-server.service (enabled and running)

### Database Configuration
- **Type**: PostgreSQL 15
- **Database**: stork
- **User**: stork
- **Password**: stork123
- **Host**: localhost
- **Port**: 5432
- **SSL Mode**: disable
- **Schema Version**: 65 (successfully migrated)

### Stork Agent - Kea DHCP Server 1 (LXC 133)
- **Hostname**: kea-dhcp-1
- **IP Address**: 192.168.1.133
- **Agent Port**: 8080
- **Prometheus Kea Exporter**: 0.0.0.0:9547
- **Prometheus BIND9 Exporter**: 0.0.0.0:9119
- **Service**: isc-stork-agent.service (enabled and running)
- **Detected Apps**: Kea (control: http://127.0.0.1:8000/)
- **Version**: ISC Stork Agent 2.2.1

### Stork Agent - Kea DHCP Server 2 (LXC 134)
- **Hostname**: kea-dhcp-2
- **IP Address**: 192.168.1.134
- **Agent Port**: 8080
- **Prometheus Kea Exporter**: 0.0.0.0:9547
- **Prometheus BIND9 Exporter**: 0.0.0.0:9119
- **Service**: isc-stork-agent.service (enabled and running)
- **Detected Apps**: Kea (control: http://127.0.0.1:8000/)
- **Version**: ISC Stork Agent 2.2.1

## Configuration Files

### Stork Server (/etc/stork/server.env)
```bash
STORK_DATABASE_HOST=localhost
STORK_DATABASE_PORT=5432
STORK_DATABASE_NAME=stork
STORK_DATABASE_USER_NAME=stork
STORK_DATABASE_PASSWORD=stork123
STORK_DATABASE_SSLMODE=disable
STORK_REST_HOST=0.0.0.0
STORK_REST_PORT=8080
STORK_REST_STATIC_FILES_DIR=/usr/share/stork/www
STORK_REST_VERSIONS_URL=https://www.isc.org/versions.json
STORK_LOG_LEVEL=INFO
```

### Stork Agent LXC 133 (/etc/stork/agent.env)
```bash
STORK_AGENT_SERVER_URL=http://192.168.1.234:8080
STORK_AGENT_HOST=192.168.1.133
STORK_AGENT_PORT=8080
```

### Stork Agent LXC 134 (/etc/stork/agent.env)
```bash
STORK_AGENT_SERVER_URL=http://192.168.1.234:8080
STORK_AGENT_HOST=192.168.1.134
STORK_AGENT_PORT=8080
```

## Next Steps

### 1. Initial Web UI Setup
1. Open web browser and navigate to http://192.168.1.234:8080
2. Complete first-time setup wizard
3. Create admin user account

### 2. Register Kea Servers
1. Log into Stork web UI
2. Navigate to Services → Machines → Add Machine
3. Add first Kea server:
   - Address: 192.168.1.133
   - Port: 8080 (agent port)
4. Add second Kea server:
   - Address: 192.168.1.134
   - Port: 8080 (agent port)

### 3. Verify HA Configuration
- Once both servers are registered, Stork will automatically detect the Kea HA configuration
- Check Dashboard for HA status between kea-dhcp-1 and kea-dhcp-2
- Verify failover pairs are correctly identified
- Monitor lease synchronization status

### 4. Configure Monitoring Alerts (Optional)
- Set up alerts for DHCP pool exhaustion
- Configure HA failover notifications
- Set thresholds for lease warnings

## Features Available

### Monitoring Capabilities
- Real-time DHCP statistics
- HA status and failover state
- Subnet utilization
- Lease allocation rates
- Pool usage percentages
- Shared network overview

### Management Features
- Centralized configuration review
- Kea configuration validation
- DHCP host reservation management
- Subnet management
- HA configuration overview

### Metrics Export
- Prometheus metrics available on both servers:
  - Kea metrics: port 9547
  - BIND9 metrics: port 9119

## Service Management

### Start/Stop/Restart Services

**Stork Server (LXC 135):**
```bash
systemctl start isc-stork-server
systemctl stop isc-stork-server
systemctl restart isc-stork-server
systemctl status isc-stork-server
```

**Stork Agent (LXC 133 & 134):**
```bash
systemctl start isc-stork-agent
systemctl stop isc-stork-agent
systemctl restart isc-stork-agent
systemctl status isc-stork-agent
```

### View Logs

**Stork Server:**
```bash
journalctl -u isc-stork-server -f
```

**Stork Agents:**
```bash
journalctl -u isc-stork-agent -f
```

## Known Limitations

1. **Expected Warnings**: Both Kea servers show errors for DHCPv6 and D2 (DDNS) daemons not being available. This is expected as only DHCPv4 is configured.

2. **Agent API**: Stork agents don't expose their own API endpoint. They only communicate with the Stork server.

## Access Information

| Component | Address | Port | Protocol |
|-----------|---------|------|----------|
| Stork Web UI | http://192.168.1.234:8080 | 8080 | HTTP |
| Stork Agent 1 | 192.168.1.133:8080 | 8080 | gRPC |
| Stork Agent 2 | 192.168.1.134:8080 | 8080 | gRPC |
| Prometheus Kea (Server 1) | 192.168.1.133:9547 | 9547 | HTTP |
| Prometheus Kea (Server 2) | 192.168.1.134:9547 | 9547 | HTTP |
| PostgreSQL | localhost:5432 | 5432 | PostgreSQL |

## Deployment Date
November 4, 2025

## Software Versions
- Stork Server: 2.2.1 (2025-08-28 14:33)
- Stork Agent: 2.2.1
- PostgreSQL: 15.14
- Kea: (already installed on LXC 133 and 134)
