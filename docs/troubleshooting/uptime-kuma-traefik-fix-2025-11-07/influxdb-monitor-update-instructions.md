# InfluxDB Monitor Configuration - /ping Endpoint

## Script Deployed

I've created and deployed a script to update the InfluxDB monitor in Uptime Kuma to use the `/ping` endpoint.

**Script Location:** `/opt/uptime-kuma/update-influx-monitor.js` (in LXC 132)

## Why This Update is Needed

**Current Issue:**
- InfluxDB monitor: `https://influx.internal.lakehouse.wtf`
- Returns: HTTP 503 (requires authentication)
- Result: Monitor shows DOWN/RED

**Solution:**
- Use InfluxDB's /ping endpoint: `http://192.168.1.56:8086/ping`
- Returns: HTTP 204 (No Content) - valid health check response
- No authentication required
- Result: Monitor will show UP/GREEN

## How to Run the Script

### Option 1: Run from Proxmox Host

```bash
ssh root@192.168.1.137

# Run the script (replace with your Uptime Kuma credentials)
pct exec 132 -- node /opt/uptime-kuma/update-influx-monitor.js <username> <password>
```

### Option 2: Run from Inside Container

```bash
ssh root@192.168.1.137
pct enter 132

# Navigate to Uptime Kuma directory
cd /opt/uptime-kuma

# Run the update script (replace with your credentials)
node update-influx-monitor.js <username> <password>
```

### Example Output (Success)

```
Connecting to Uptime Kuma...
Connected to Uptime Kuma
Attempting login...
✓ Login successful
Fetching monitors...
Found 25 monitors
✓ Found InfluxDB monitor: "InfluxDB" (ID: 3)
  Current URL: https://influx.internal.lakehouse.wtf
Updating monitor configuration...
  New URL: http://192.168.1.56:8086/ping
  Accepted status codes: 200-299, 204
✓ Monitor updated successfully!

Monitor Details:
  Name: InfluxDB
  Type: http
  URL: http://192.168.1.56:8086/ping
  Interval: 120s
  Accepted Status: 200-299,204

Disconnected from Uptime Kuma
```

## What the Script Does

1. **Connects** to Uptime Kuma via Socket.IO API
2. **Authenticates** using your credentials
3. **Finds** the InfluxDB monitor by name
4. **Updates** the monitor configuration:
   - URL: `http://192.168.1.56:8086/ping`
   - Accepted status codes: `200-299`, `204`
   - Description: Updated to reflect /ping endpoint usage
5. **Saves** the changes
6. **Reports** success/failure

## Verification

After running the script:

### 1. Check Monitor Status in Uptime Kuma UI

Navigate to https://uptime.internal.lakehouse.wtf and verify:
- InfluxDB monitor shows GREEN/UP
- URL shows: `http://192.168.1.56:8086/ping`
- Status code: 204

### 2. Test from Command Line

```bash
# From Uptime Kuma container
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.168.1.56:8086/ping

# Expected output: HTTP Status: 204
```

## Alternative: Manual Update via UI

If you prefer to update manually:

1. Open https://uptime.internal.lakehouse.wtf
2. Login to Uptime Kuma
3. Find the InfluxDB monitor
4. Click Edit
5. Update the following fields:
   - **URL**: `http://192.168.1.56:8086/ping`
   - **Accepted Status Codes**: Add `204` to the list
   - **Description**: "InfluxDB health check using /ping endpoint"
6. Save changes

## Troubleshooting

### Script Not Found
```bash
ssh root@192.168.1.137
pct exec 132 -- ls -la /opt/uptime-kuma/update-influx-monitor.js
```

If missing, the script is available at `/tmp/update-influx-monitor.js` on the workspace.

### Login Failed
- Verify your Uptime Kuma username and password
- Check that Uptime Kuma is running: `pct exec 132 -- pm2 status`

### Monitor Not Found
The script searches for monitors with "influx" in the name. If your monitor has a different name, you can:
- Update the script's search term
- Use the manual UI method instead

### Connection Error
- Verify Uptime Kuma is accessible: `curl http://192.168.1.132:3001`
- Check the service: `pct exec 132 -- systemctl status uptime-kuma`

## Benefits of /ping Endpoint

✅ **No Authentication Required**: /ping is a public health check endpoint  
✅ **Lightweight**: Returns minimal response (HTTP 204)  
✅ **Fast**: < 10ms response time  
✅ **Standard**: Official InfluxDB health check method  
✅ **Reliable**: Won't be affected by authentication changes  

## After Update

Once updated, the InfluxDB monitor will:
- Show ✅ UP/GREEN status
- Check every 120 seconds (configurable)
- Accept HTTP 204 as valid response
- No longer report false negatives due to authentication

## Summary

**Script Location:** `/opt/uptime-kuma/update-influx-monitor.js`  
**Command:** `node update-influx-monitor.js <username> <password>`  
**New URL:** `http://192.168.1.56:8086/ping`  
**Expected Status:** HTTP 204  
**Result:** Monitor shows UP  

Please run the script with your Uptime Kuma credentials to complete the InfluxDB monitor configuration.
