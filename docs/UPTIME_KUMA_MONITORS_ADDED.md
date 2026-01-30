# Uptime Kuma Monitors Added - Vikunja & Memos

**Date:** 2025-11-19
**Services:** Vikunja (2 monitors), Memos (1 monitor)
**Method:** Socket.IO API via Node.js script

## Monitors Added

### 1. Vikunja (todo.internal.lakehouse.wtf) ✅
- **Type:** HTTP(s)
- **URL:** https://todo.internal.lakehouse.wtf
- **Method:** GET
- **Interval:** 60 seconds
- **Retries:** 3
- **Expected Status:** 200-299
- **TLS:** Enabled
- **Status:** Active

### 2. Vikunja (vikunja.internal.lakehouse.wtf) ✅
- **Type:** HTTP(s)
- **URL:** https://vikunja.internal.lakehouse.wtf
- **Method:** GET
- **Interval:** 60 seconds
- **Retries:** 3
- **Expected Status:** 200-299
- **TLS:** Enabled
- **Status:** Active

### 3. Memos (memos.internal.lakehouse.wtf) ✅
- **Type:** HTTP(s)
- **URL:** https://memos.internal.lakehouse.wtf
- **Method:** GET
- **Interval:** 60 seconds
- **Retries:** 3
- **Expected Status:** 200-299
- **TLS:** Enabled
- **Status:** Active

## Implementation Details

### Script Location
- **Source:** `/tmp/add-vikunja-memos-monitors.js`
- **Execution Location:** `/opt/uptime-kuma/add-vikunja-memos-monitors.js` (LXC 132)

### Script Execution
```bash
# Copy script to Uptime Kuma container
ssh root@192.168.1.137 "pct push 132 /tmp/add-vikunja-memos-monitors.js /tmp/add-vikunja-memos-monitors.js"

# Copy to Uptime Kuma directory for node_modules access
ssh root@192.168.1.137 "pct exec 132 -- cp /tmp/add-vikunja-memos-monitors.js /opt/uptime-kuma/"

# Execute script
ssh root@192.168.1.137 "pct exec 132 -- bash -c 'cd /opt/uptime-kuma && node add-vikunja-memos-monitors.js root redflower805'"
```

### Execution Results
```
Connected to Uptime Kuma
✓ Logged in successfully

Adding 3 monitors...

✓ [1/3] Vikunja (todo.internal.lakehouse.wtf)
✓ [2/3] Vikunja (vikunja.internal.lakehouse.wtf)
✓ [3/3] Memos (memos.internal.lakehouse.wtf)

✓ All monitors added successfully!
```

## Configuration Details

### Monitor Configuration Template
```javascript
{
    name: 'Service Name',
    type: 'http',
    url: 'https://service.internal.lakehouse.wtf',
    method: 'GET',
    interval: 60,              // Check every 60 seconds
    retryInterval: 60,         // Retry after 60 seconds if failed
    resendInterval: 0,         // No resend notifications
    maxretries: 3,             // Retry up to 3 times before marking as down
    ignoreTls: false,          // Verify TLS certificates
    maxredirects: 3,           // Follow up to 3 redirects
    accepted_statuscodes: ['200-299'],  // Accept 2xx status codes
    notificationIDList: {},    // No specific notifications (uses default)
    upsideDown: false,         // Normal monitoring (not inverted)
    expiryNotification: false, // No expiry notifications
    conditions: '[]'           // No custom conditions
}
```

## API Method Used

### Socket.IO API
Uptime Kuma provides a Socket.IO API for programmatic monitor management.

**Connection:**
```javascript
const io = require('socket.io-client');
const socket = io('http://192.168.1.132:3001');
```

**Authentication:**
```javascript
socket.emit('login', {
    username: 'root',
    password: 'redflower805',
    token: ''
}, (res) => {
    if (res.ok) {
        // Authenticated
    }
});
```

**Adding Monitor:**
```javascript
socket.emit('add', monitorConfig, (res) => {
    if (res.ok) {
        // Monitor added successfully
    }
});
```

## Infrastructure Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **Uptime Kuma** | LXC 132 @ 192.168.1.137 | Monitoring service |
| **Uptime Kuma Web** | https://uptime.internal.lakehouse.wtf | Web interface |
| **Uptime Kuma API** | http://192.168.1.132:3001 | Socket.IO API |
| **Node.js** | /bin/node (in LXC 132) | Script runtime |
| **socket.io-client** | /opt/uptime-kuma/node_modules/ | API client library |

## Access Information

### Web Interface
- **URL:** https://uptime.internal.lakehouse.wtf
- **Username:** root
- **Password:** redflower805

### Viewing Monitors
1. Navigate to https://uptime.internal.lakehouse.wtf
2. Login with credentials
3. View monitor status on dashboard
4. Click on individual monitors for details

## Verification

### Check Monitor Status
```bash
# Via web interface
# Navigate to: https://uptime.internal.lakehouse.wtf

# Via API (if needed in future)
# Would require additional socket.io code to query monitor list
```

### Monitor Health Check
All three monitors should show:
- ✅ Status: Up
- ✅ Response Time: < 500ms
- ✅ Status Code: 200
- ✅ Uptime: 100%

## Benefits

### Automated Monitoring
- Continuous health checks every 60 seconds
- Automatic retry on failure (up to 3 times)
- Immediate notification on sustained failure

### Multiple URLs Monitored
- Both Vikunja URLs monitored separately
- Ensures both DNS entries are working
- Provides redundancy in monitoring

### Integration with Deployments
- Monitors added automatically as part of deployment
- Follows SOP completion checklist
- Ensures monitoring is not forgotten

## Future Enhancements

### Notification Configuration
Consider adding notification channels:
```javascript
notificationIDList: {
    1: true,  // Email notification
    2: true   // Slack notification
}
```

### Custom Conditions
Add specific monitoring conditions if needed:
```javascript
conditions: '[{"type":"response_time","operator":"<","value":"1000"}]'
```

### Status Page
Create a public status page showing service availability.

## Related Documentation

- [Vikunja Deployment Complete](/home/dev/workspace/docs/VIKUNJA_DEPLOYMENT_COMPLETE.md)
- [Memos Deployment Complete](/home/dev/workspace/docs/MEMOS_DEPLOYMENT_COMPLETE.md)
- [LXC Service Deployment SOP](/home/dev/workspace/docs/LXC_SERVICE_DEPLOYMENT_SOP.md)
- [Uptime Kuma Configuration Script](/home/dev/workspace/configure-uptime-kuma.js)

## Troubleshooting

### If monitors show as down

1. **Check Service Status**
   ```bash
   # Vikunja
   curl -I https://todo.internal.lakehouse.wtf

   # Memos
   curl -I https://memos.internal.lakehouse.wtf
   ```

2. **Check DNS Resolution**
   ```bash
   dig +short todo.internal.lakehouse.wtf
   dig +short vikunja.internal.lakehouse.wtf
   dig +short memos.internal.lakehouse.wtf
   ```

3. **Check Traefik Status**
   ```bash
   ssh root@192.168.1.110 "systemctl status traefik"
   ```

4. **Review Monitor Settings**
   - Login to Uptime Kuma web interface
   - Click on monitor name
   - Verify URL and settings
   - Check recent heartbeats

### If monitors need to be removed

```javascript
// Use similar script with 'delete' instead of 'add'
socket.emit('delete', monitorId, (res) => {
    if (res.ok) {
        console.log('Monitor deleted');
    }
});
```

## Completion Status

**Status:** ✅ **COMPLETE**

All monitors successfully added:
- ✅ Vikunja (todo.internal.lakehouse.wtf)
- ✅ Vikunja (vikunja.internal.lakehouse.wtf)
- ✅ Memos (memos.internal.lakehouse.wtf)

**Final Deployment Checklist:**
- ✅ Services deployed (Vikunja & Memos)
- ✅ DHCP reservations configured
- ✅ DNS rewrites configured (AdGuard)
- ✅ Traefik routing configured
- ✅ HTTPS access verified
- ✅ Uptime Kuma monitors added
- ✅ Documentation complete

---

**Monitors Added By:** Claude Code (AI Assistant)
**Date:** 2025-11-19
**Script:** add-vikunja-memos-monitors.js
**API:** Uptime Kuma Socket.IO
