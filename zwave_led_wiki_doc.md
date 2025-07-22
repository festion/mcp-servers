# Z-Wave LED Control Automation Troubleshooting Guide

**Date:** July 1, 2025  
**Project:** Home Assistant Configuration  
**Issue:** Z-Wave LED control automation not working - HTTP 500 errors  
**Status:** Diagnostics implemented, awaiting device identification  

## Problem Summary

The Z-Wave LED control automation was failing to control device LEDs with HTTP 500 Internal Server Error responses. The automation is designed to dim LED indicators on switches and fans during night hours (10 PM - 7 AM).

### Symptoms
- Z-Wave service calls returning HTTP 500 errors
- Basic device control (on/off) works successfully
- Automation runs but LED parameter setting fails
- No visible LED behavior changes

### Affected Devices
- **Lights:** hobby_light, gavin_light, pantry_light, master_light, nook_light, guest_light, porch_light, hall_light, dining_light, linda_light
- **Fans:** hobby_fan, master_fan, linda_fan, guest_fan, gavin_fan

## Root Cause Analysis

### Initial Assumptions (Unverified)
- Devices claimed to be Leviton DZ1KD (lights) and ZW4SF (fans)
- Parameter 7 for light switches (DZ1KD)
- Parameter 3 for fan switches (ZW4SF)

### Discovered Issues
1. **HTTP 500 Errors:** Z-Wave parameter setting services failing
2. **Device Type Uncertainty:** Devices may not actually be Z-Wave devices
3. **Integration Mismatch:** Devices might use Zigbee, WiFi, or other protocols
4. **Parameter Mapping:** Incorrect parameter numbers for actual device models

## Implemented Solutions

### 1. Diagnostic Scripts Created

#### Z-Wave LED Test Script
Manual test script for Z-Wave LED parameter setting:
- Tests multiple parameter values (3, 7, 13, 16, 22)
- Tests both `zwave_js.set_config_parameter` and `zwave_js.set_value` services
- Includes device ping testing
- Comprehensive logging for troubleshooting

#### Device Integration Check Script
Device integration identification script:
- Checks device model, manufacturer, and integration type
- Tests Z-Wave ping and Zigbee cluster commands
- Logs device attributes for analysis
- Identifies actual integration managing each device

#### Enhanced Scripts Configuration
Added three new diagnostic scripts:
- `zwave_led_hobby_test` - Test individual device LED control
- `identify_device_integrations` - Check integration types
- `check_device_models` - Log device information

### 2. Enhanced Automation Error Handling

#### Modified Z-Wave LED Control Automation
- **Device Information Logging:** Added model/manufacturer logging for troubleshooting
- **Multiple Parameter Testing:** Tests both parameter 7 and 3 for each device
- **Alternative Service Calls:** Added `zwave_js.set_value` as backup method
- **Better Error Handling:** Enhanced `continue_on_error` usage
- **Timing Controls:** Added timestamp-based duplicate prevention

#### Added Input DateTime Entities
Created timing controls:
```yaml
zwave_led_last_night_run:
  name: "Z-Wave LED Last Night Mode Run"
  has_date: true
  has_time: true
  icon: mdi:led-outline

zwave_led_last_day_run:
  name: "Z-Wave LED Last Day Mode Run"
  has_date: true
  has_time: true
  icon: mdi:led-outline
```

### 3. Automation Timing Improvements

#### Night Mode Automation (10 PM)
- Added condition to prevent double execution within 1 hour
- Timestamp logging at start of execution
- Enhanced device identification logging

#### Day Mode Automation (7 AM)
- Similar timing controls as night mode
- Improved error handling and logging
- Better device availability checking

#### Manual Control Automation
- Maintains existing functionality
- Enhanced with better logging for troubleshooting

## Diagnostic Process

### Step 1: Run Device Model Check
```yaml
service: script.check_device_models
```
**Purpose:** Identify actual device manufacturers, models, and integrations

### Step 2: Run Integration Identification
```yaml
service: script.identify_device_integrations
```
**Purpose:** Determine which Home Assistant integration manages each device

### Step 3: Test Individual Device LED Control
```yaml
service: script.zwave_led_hobby_test
```
**Purpose:** Test Z-Wave parameter setting with multiple approaches

### Step 4: Analyze Logs
Check Home Assistant logs for:
- Device model/manufacturer information
- Integration type identification
- Service call success/failure details
- Error messages and response codes

## Expected Outcomes

### If Devices Are Z-Wave
- Diagnostic scripts will show Z-Wave integration
- Parameter testing will identify correct parameter numbers
- Update automation with correct parameters

### If Devices Are Not Z-Wave
- Scripts will identify actual integration (Zigbee, WiFi, etc.)
- Need to replace Z-Wave service calls with appropriate integration services
- Update automation to use correct LED control methods

## Implementation Summary

### Modified Files
1. Z-Wave LED control automation - Enhanced error handling and diagnostics
2. Scripts configuration - Added diagnostic scripts
3. Input datetime configuration - Added timing control entities

### Created Diagnostic Scripts
1. Manual Z-Wave LED testing script
2. Device integration identification script

## Next Steps

1. **Run Diagnostic Scripts** via Home Assistant Developer Tools > Services
2. **Analyze Results** in Home Assistant logs and logbook
3. **Identify Actual Device Types** from diagnostic output
4. **Update Automation** based on discovered integration and parameter requirements
5. **Test LED Control** with correct integration services
6. **Validate Automation** during next scheduled run (10 PM/7 AM)

## Technical Details

### Z-Wave Service Calls Tested
- `zwave_js.set_config_parameter` with parameters 3 and 7
- `zwave_js.set_value` with command class 112 (Configuration)
- `zwave_js.ping` for connectivity testing

### Alternative Integration Methods
- Zigbee cluster commands (for ZHA devices)
- Custom device attributes (for WiFi devices)
- Integration-specific LED control services

### Error Handling Strategy
- `continue_on_error: true` for all LED control calls
- Comprehensive logging before and after each attempt
- Multiple parameter and service testing per device
- Timestamp-based execution tracking

## Troubleshooting Context

This troubleshooting was part of a larger Home Assistant system audit and remediation process that included:
1. Template rendering error fixes
2. Adaptive lighting deprecation warnings resolution
3. Z-Wave LED control automation issues (this document)

The diagnostic framework established here can be reused for similar device identification and integration troubleshooting scenarios.

## Key Learnings

- Always verify actual device integration before assuming Z-Wave compatibility
- HTTP 500 errors often indicate service/integration mismatch rather than parameter issues
- Comprehensive logging is essential for diagnosing device control problems
- Multiple parameter testing helps identify correct device configuration
- Timing controls prevent automation execution conflicts