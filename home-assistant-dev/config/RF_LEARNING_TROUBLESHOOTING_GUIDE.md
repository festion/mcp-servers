# =============================================================================
# RF LEARNING TROUBLESHOOTING AND TESTING GUIDE
# =============================================================================

## STEP 1: DEVELOPER TOOLS TEST (MANDATORY FIRST STEP)

**Before running any scripts, test RF learning manually in Developer Tools:**

1. **Navigate to:** Settings > Developer Tools > Services
2. **Search for:** remote.learn_command
3. **Configure the service call:**

```yaml
service: remote.learn_command
target:
  entity_id: remote.rm4_pro
data:
  device: "test_rf_device"
  command: "test_power"
  command_type: rf
  timeout: 60
```

4. **Press "Call Service"**
5. **Watch for notifications** - you should see HA notification prompts
6. **Follow the two-step process:**
   - Step 1: Press and HOLD button for 3-5 seconds
   - Step 2: Press button normally when prompted

**Expected Results:**
- ✅ SUCCESS: "Command learned successfully" notification
- ❌ FAILURE: "No infrared code received" (means RF not working)

## STEP 2: TROUBLESHOOTING RF LEARNING ISSUES

**If Developer Tools test fails with "No infrared code received":**

### Option A: RM4 Pro Firmware Issue
Your RM4 Pro might need firmware update or RF module activation:
1. **Update Broadlink app** to latest version
2. **Update RM4 Pro firmware** through Broadlink app
3. **Test RF learning in Broadlink app first**
4. **Verify RF capability** is working in app before using HA

### Option B: Alternative RF Learning Method
Try using the `alternative: true` parameter for difficult RF signals:

```yaml
service: remote.learn_command
target:
  entity_id: remote.rm4_pro
data:
  device: "outdoor_ceiling_fan"
  command: "power"
  command_type: rf
  alternative: true
  timeout: 60
```

### Option C: Command Line Tool Method
If HA integration has issues, use broadlink_cli directly:

1. **Install broadlink_cli:**
   ```bash
   pip install broadlink
   ```

2. **Discover device:**
   ```bash
   broadlink_discovery
   ```

3. **Learn RF codes:**
   ```bash
   broadlink_cli --rfscanlearn --device "DEVICE_INFO"
   ```

4. **Convert to HA format** using base64 codes

## STEP 3: VERIFY HOME ASSISTANT VERSION COMPATIBILITY

**Your HA Version:** 2025.6.0

**Known Issues:**
- Some HA 2025.x versions have Broadlink integration changes
- RF learning parameter syntax may have changed
- Integration may require restart after configuration

**Quick Fixes:**
1. **Restart Home Assistant** completely
2. **Reload Broadlink integration:** Settings > Devices & Services > Broadlink > Reload
3. **Check integration version:** Ensure you have latest Broadlink integration

## STEP 4: ALTERNATIVE SCRIPT SYNTAX

If the current scripts don't work, try this alternative syntax that some users report working:

```yaml
learn_outdoor_fan_power_alt:
  alias: "Learn RF Power (Alternative Syntax)"
  sequence:
    - service: remote.learn_command
      data:
        entity_id: remote.rm4_pro
        device: "outdoor_ceiling_fan"
        command: "power"
        command_type: "rf"
        timeout: 60
```

**Key Differences:**
- Quoted `"rf"` instead of unquoted `rf`
- `entity_id` in data instead of target section
- Explicit timeout parameter

## STEP 5: NETWORK DIAGNOSTICS

**If RF learning completely fails:**

1. **Check RM4 Pro Network Status:**
   - Verify device is online in HA
   - Check network connectivity
   - Ensure no firewall blocking

2. **Test Basic IR Learning First:**
   ```yaml
   service: remote.learn_command
   target:
     entity_id: remote.rm4_pro
   data:
     device: "test_ir_device"
     command: "test_ir"
     timeout: 30
   ```

3. **If IR works but RF doesn't:**
   - RF module may be disabled
   - Firmware issue with RF capability
   - Hardware limitation

## STEP 6: SUCCESS VERIFICATION

**When RF learning succeeds:**

1. **Check learned codes file:**
   - Path: `/config/.storage/broadlink_remote_MACADDRESS_codes`
   - Look for your device and commands
   - Verify RF codes are longer than IR codes

2. **Test sending commands:**
   ```yaml
   service: remote.send_command
   target:
     entity_id: remote.rm4_pro
   data:
     device: "outdoor_ceiling_fan"
     command: "power"
   ```

3. **Monitor Home Assistant logs:**
   - Settings > System > Logs
   - Look for Broadlink integration messages
   - Check for any RF-related errors

## DIAGNOSTIC COMMANDS

**Check RM4 Pro entity status:**
```yaml
service: homeassistant.update_entity
data:
  entity_id: remote.rm4_pro
```

**Check Broadlink integration health:**
```yaml
service: system_log.write
data:
  level: info
  message: "Testing Broadlink RF integration"
```

**Reload Broadlink integration:**
1. Settings > Devices & Services
2. Find Broadlink integration
3. Click three dots menu > Reload

## NEXT STEPS BASED ON RESULTS

**If Developer Tools RF test succeeds:**
- ✅ Use the corrected scripts (they should work)
- ✅ Run `script.learn_all_outdoor_fan_codes_official`

**If Developer Tools RF test fails:**
- ❌ RF capability issue with device/firmware
- ❌ Need to use Broadlink app method
- ❌ May need different RM4 Pro model

**Current Error Analysis:**
Your error "No infrared code received within 30.0 seconds" suggests:
1. HA is not recognizing `command_type: rf` parameter
2. Still defaulting to IR mode (30s timeout vs our 60s)
3. Either syntax issue or integration problem

**Immediate Action Required:**
1. **Test in Developer Tools first** (Step 1 above)
2. **Report back results** before running any scripts
3. **Check RM4 Pro firmware** if RF learning fails
