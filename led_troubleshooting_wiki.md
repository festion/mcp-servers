# LED Control Automation Troubleshooting Guide

**Date:** July 1, 2025  
**Issue:** LED control automation not working - HTTP 500 errors  
**Status:** Diagnostics implemented, awaiting device identification  

## Problem Summary

LED control automation was failing to control device LED indicators with HTTP 500 Internal Server Error responses. The automation is designed to dim LED indicators on switches and fans during night hours.

### Symptoms
- Service calls returning HTTP 500 errors
- Basic device control works successfully
- Automation runs but LED parameter setting fails
- No visible LED behavior changes

## Root Cause Analysis

### Initial Assumptions
- Devices assumed to be specific models with known LED parameters
- Incorrect parameter numbers for actual device models
- Integration mismatch between assumed and actual device types

### Discovered Issues
1. **HTTP 500 Errors:** Parameter setting services failing
2. **Device Type Uncertainty:** Devices may not match assumed integration
3. **Integration Mismatch:** Devices might use different protocols
4. **Parameter Mapping:** Incorrect parameter numbers for actual device models

## Implemented Solutions

### 1. Diagnostic Scripts Created

#### LED Test Script
Manual test script for LED parameter setting:
- Tests multiple parameter values
- Tests different service call methods
- Includes device connectivity testing
- Comprehensive logging for troubleshooting

#### Device Integration Check Script
Device integration identification script:
- Checks device model, manufacturer, and integration type
- Tests different integration commands
- Logs device attributes for analysis
- Identifies actual integration managing each device

### 2. Enhanced Automation Error Handling

#### Modified LED Control Automation
- **Device Information Logging:** Added model/manufacturer logging
- **Multiple Parameter Testing:** Tests various parameter values
- **Alternative Service Calls:** Added backup methods
- **Better Error Handling:** Enhanced error recovery
- **Timing Controls:** Added duplicate prevention

#### Added Timing Controls
Created timestamp-based execution tracking to prevent conflicts.

### 3. Automation Timing Improvements

#### Night Mode Automation
- Added condition to prevent double execution
- Timestamp logging at start of execution
- Enhanced device identification logging

#### Day Mode Automation
- Similar timing controls as night mode
- Improved error handling and logging
- Better device availability checking

## Diagnostic Process

### Step 1: Run Device Model Check
Identify actual device manufacturers, models, and integrations

### Step 2: Run Integration Identification
Determine which integration manages each device

### Step 3: Test Individual Device LED Control
Test parameter setting with multiple approaches

### Step 4: Analyze Logs
Check system logs for:
- Device model/manufacturer information
- Integration type identification
- Service call success/failure details
- Error messages and response codes

## Expected Outcomes

### If Devices Match Assumed Integration
- Diagnostic scripts will confirm integration type
- Parameter testing will identify correct parameter numbers
- Update automation with correct parameters

### If Devices Use Different Integration
- Scripts will identify actual integration
- Need to replace service calls with appropriate integration services
- Update automation to use correct LED control methods

## Technical Details

### Service Calls Tested
- Primary parameter setting services
- Alternative value setting methods
- Device connectivity testing

### Alternative Integration Methods
- Different protocol cluster commands
- Custom device attributes
- Integration-specific LED control services

### Error Handling Strategy
- Continue on error for all LED control calls
- Comprehensive logging before and after each attempt
- Multiple parameter and service testing per device
- Timestamp-based execution tracking

## Key Learnings

- Always verify actual device integration before assuming compatibility
- HTTP 500 errors often indicate service/integration mismatch
- Comprehensive logging is essential for diagnosing device control problems
- Multiple parameter testing helps identify correct device configuration
- Timing controls prevent automation execution conflicts

## Next Steps

1. Run diagnostic scripts via Developer Tools
2. Analyze results in system logs
3. Identify actual device types from diagnostic output
4. Update automation based on discovered integration requirements
5. Test LED control with correct integration services
6. Validate automation during next scheduled run