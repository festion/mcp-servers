# 🚀 Appliance Notifications Fix - Deployment Guide

## Changes Made
- ✅ Fixed "-297 minutes" bug in completion announcements
- ✅ Enhanced washing machine reminders to check dryer status  
- ✅ Disabled dishwasher follow-up reminders (kept completion announcements)
- ✅ Added context-aware messaging for better UX

## Deployment Options

### Option 1: Manual Copy via Network Share
1. Open File Explorer on Windows or Finder on Mac
2. Navigate to `\\192.168.1.155\config` (or `smb://192.168.1.155/config` on Mac)
3. Login with credentials:
   - Username: `homeassistant`
   - Password: `reedflower805`
   - Domain: `homelab`
4. Navigate to the `automations` folder
5. **Backup existing files** (recommended):
   - Copy `appliances.yaml` → `appliances_backup_$(date).yaml`
   - Copy `appliance.yaml` → `appliance_backup_$(date).yaml`
6. Copy the updated files from this repository:
   - Copy `automations/appliances.yaml` to `\\192.168.1.155\config\automations\appliances.yaml`
   - Copy `automations/appliance.yaml` to `\\192.168.1.155\config\automations\appliance.yaml`

### Option 2: SSH/SCP (if SSH is enabled)
```bash
# Backup existing files
ssh homeassistant@192.168.1.155 "cd /config/automations && cp appliances.yaml appliances_backup_$(date +%Y%m%d).yaml"
ssh homeassistant@192.168.1.155 "cd /config/automations && cp appliance.yaml appliance_backup_$(date +%Y%m%d).yaml"

# Deploy new files
scp automations/appliances.yaml homeassistant@192.168.1.155:/config/automations/
scp automations/appliance.yaml homeassistant@192.168.1.155:/config/automations/
```

### Option 3: Home Assistant File Editor Add-on
1. Open Home Assistant → Add-ons → File Editor
2. Navigate to `/config/automations/`
3. Edit `appliances.yaml` and `appliance.yaml` manually with the changes
4. Save the files

## Post-Deployment Steps

### 1. Validate Configuration
1. Go to **Home Assistant** → **Developer Tools** → **YAML**
2. Click **"Check Configuration"**
3. Wait for validation to complete
4. If errors appear, check the automation syntax

### 2. Reload/Restart
Choose one:
- **Quick Option**: Developer Tools → YAML → "Reload Automations"
- **Full Option**: Developer Tools → YAML → "Restart"

### 3. Test the Changes
1. **Washing Machine Test**:
   - Start a washing machine cycle
   - Verify completion announcement doesn't say "after -297 minutes"
   - Check that reminders consider dryer status

2. **Dishwasher Test**:
   - Start a dishwasher cycle  
   - Verify completion announcement still works
   - Confirm no follow-up reminders are sent

## Files Changed
- `automations/appliances.yaml` - Main smart appliance system
- `automations/appliance.yaml` - Basic notification system

## Commit Reference
- **Commit**: `9f56ad0`
- **Message**: "Fix appliance notification issues and enhance washing machine logic"

## Troubleshooting

### If Configuration Check Fails
1. Check YAML syntax in the automation files
2. Restore from backup files if needed
3. Review Home Assistant logs for specific errors

### If Automations Don't Trigger
1. Go to Developer Tools → Events
2. Check automation traces
3. Verify entity names match your Home Assistant setup
4. Check automation conditions (time, entity states)

### If SMB Connection Issues
- Verify Home Assistant Samba add-on is running
- Check firewall settings on Home Assistant
- Try accessing via IP address vs hostname
- Ensure credentials are correct

## Support
- Home Assistant logs: **Settings** → **System** → **Logs**
- Automation traces: **Settings** → **Automations & Scenes** → Select automation → **Traces**