# ========================================================================
# OUTDOOR CEILING FAN BROADLINK RM4 PRO CONFIGURATION - COMPLETION GUIDE
# ========================================================================
# Created: June 11, 2025
# Status: Ready for IR Code Learning

## 🎯 WHAT HAS BEEN COMPLETED

### ✅ Infrastructure Setup
- ✅ Broadlink RM4 Pro confirmed online and working (`remote.rm4_pro`)
- ✅ Outdoor ceiling fan package configuration created (`packages/outdoor_ceiling_fan.yaml`)
- ✅ Learning scripts added to `scripts.yaml` (13 new scripts)
- ✅ Dashboard created for learning process (`dashboards/outdoor_ceiling_fan_dashboard.yaml`)
- ✅ Configuration updated to include new dashboard
- ✅ Logging enhanced for Broadlink debugging

### ✅ Learning Scripts Available
1. **`script.learn_all_outdoor_fan_codes`** - Complete automated learning sequence
2. **`script.learn_outdoor_fan_power_on`** - Learn power ON command
3. **`script.learn_outdoor_fan_power_off`** - Learn power OFF command
4. **`script.learn_outdoor_fan_speed_low`** - Learn low speed
5. **`script.learn_outdoor_fan_speed_medium`** - Learn medium speed
6. **`script.learn_outdoor_fan_speed_high`** - Learn high speed
7. **`script.learn_outdoor_fan_light_on`** - Learn light ON (optional)
8. **`script.learn_outdoor_fan_light_off`** - Learn light OFF (optional)
9. **`script.learn_outdoor_fan_reverse`** - Learn reverse direction (optional)
10. **`script.test_outdoor_fan_codes`** - Test all learned codes

### ✅ Dashboard Features
- Complete learning interface with progress tracking
- Step-by-step guidance for IR code learning
- Testing and validation tools
- Troubleshooting guide and tips
- Current fan controls (will appear after learning)

## 🚀 NEXT STEPS - READY TO EXECUTE

### STEP 1: Restart Home Assistant (REQUIRED)
```bash
# Restart to load new scripts and dashboard
# Go to: Settings > System > Restart
```

### STEP 2: Access the Learning Dashboard
1. Go to Home Assistant sidebar
2. Click "Outdoor Ceiling Fan" dashboard
3. You'll see the complete learning interface

### STEP 3: Position Equipment
1. **Position RM4 Pro**: 6-12 inches from your ceiling fan remote
2. **Check Remote**: Ensure fresh batteries in ceiling fan remote
3. **Clear Path**: Ensure line of sight between remote, RM4 Pro, and fan

### STEP 4: Start Learning Process
**Option A: Automated Learning (RECOMMENDED)**
1. Click "🚀 Start Complete Learning Process"
2. Follow the prompts for each button
3. Have your remote ready for 8 button presses

**Option B: Manual Learning**
1. Learn each command individually using the dashboard buttons
2. Start with power commands, then speeds, then optional features

### STEP 5: Test Learned Codes
1. After learning, click "🎯 Test All Learned Codes"
2. Watch your ceiling fan respond to each command
3. Re-learn any commands that don't work properly

### STEP 6: Extract and Apply Codes
After successful learning, you'll need to:

1. **Find the codes** in `.storage/broadlink_remote_e87072ba7282_codes`
2. **Look for new section** like:
   ```json
   "outdoor_ceiling_fan": {
     "power_on": "JgBQAAABKZMT...",
     "power_off": "JgBQAAABKZMT...",
     "speed_low": "JgBQAAABKZMT...",
     "speed_medium": "JgBQAAABKZMT...",
     "speed_high": "JgBQAAABKZMT..."
   }
   ```

3. **Update the package configuration** by replacing placeholder codes in:
   `packages/outdoor_ceiling_fan.yaml`

4. **Replace these placeholder lines:**
   ```yaml
   command_on: "POWER_ON_CODE_TO_BE_LEARNED"
   ```
   **With actual codes:**
   ```yaml
   command_on: "JgBQAAABKZMT..."
   ```

5. **Restart Home Assistant** again to apply the new codes

### STEP 7: Final Testing
After applying codes:
1. Use the fan controls in the dashboard
2. Test via `input_select.outdoor_ceiling_fan_speed`
3. Test light controls via `input_boolean.outdoor_ceiling_fan_light_switch`
4. Verify `fan.outdoor_ceiling_fan` entity works properly

## 🛠️ TROUBLESHOOTING GUIDE

### Problem: Scripts Don't Appear
**Solution:** Restart Home Assistant to load new scripts

### Problem: Dashboard Not Visible
**Solution:** Check configuration.yaml was updated properly and restart HA

### Problem: Codes Not Learning
**Solutions:**
- Move RM4 Pro closer to remote (6-12 inches)
- Check remote battery level
- Try learning the same command multiple times
- Ensure no IR interference from other devices

### Problem: Inconsistent Command Execution
**Solutions:**
- Check RM4 Pro position relative to ceiling fan IR receiver
- Re-learn problematic commands
- Verify line of sight between RM4 Pro and ceiling fan

### Problem: Some Remote Buttons Don't Work
**Solutions:**
- Check ceiling fan manual for button functions
- Some fans use toggle commands (same code for on/off)
- Try learning "power" instead of separate "power_on"/"power_off"

## 📂 FILES CREATED/MODIFIED

### New Files:
- `outdoor_ceiling_fan_learning_guide.yaml` - Complete learning reference
- `dashboards/outdoor_ceiling_fan_dashboard.yaml` - Learning interface

### Modified Files:
- `scripts.yaml` - Added 10 learning and testing scripts
- `configuration.yaml` - Added dashboard, logging, and recorder settings
- `packages/outdoor_ceiling_fan.yaml` - Already existed, ready for codes

## 📱 VALIDATION WITH HOME ASSISTANT MCP

After learning codes, you can validate entities using:
```
# Check if entities were created properly
get_entity('input_select.outdoor_ceiling_fan_speed')
get_entity('input_boolean.outdoor_ceiling_fan_light_switch') 
get_entity('fan.outdoor_ceiling_fan')

# Check switch entities for IR commands
get_entity('switch.outdoor_ceiling_fan_power')
get_entity('switch.outdoor_ceiling_fan_speed_low')
get_entity('switch.outdoor_ceiling_fan_speed_medium')
get_entity('switch.outdoor_ceiling_fan_speed_high')
```

## 🎯 SUCCESS CRITERIA

You'll know the setup is complete when:
- ✅ All learning scripts are available in Home Assistant
- ✅ Outdoor Ceiling Fan dashboard is accessible
- ✅ IR codes are successfully learned (8 commands minimum)
- ✅ Test script makes ceiling fan respond correctly
- ✅ Configuration updated with actual codes
- ✅ `fan.outdoor_ceiling_fan` entity controls the physical fan
- ✅ Dashboard controls work for speed and light

## 📞 NEED HELP?

If you encounter issues:
1. Check Home Assistant logs for Broadlink errors
2. Verify RM4 Pro device status in the dashboard
3. Review the troubleshooting section above
4. Test individual commands manually through Developer Tools

The system is now ready for you to learn your outdoor ceiling fan's IR codes!