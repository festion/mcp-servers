# Tuya Local Integration Deprecation Fix - Sept 8, 2025

## Issue Resolved
Fixed Tuya Local integration deprecation warnings in Home Assistant production (192.168.1.155):
- "The use of number_timer for RGBCW Lightbulb is deprecated and should be replaced by time.timer"
- "The use of number_irrigation_time_1 for Dual water timer is deprecated and should be replaced by time.irrigation_time_1"
- "The use of number_irrigation_time_2 for Dual water timer is deprecated and should be replaced by time.irrigation_time_2"

## Files Modified
1. **custom_components/tuya_local/devices/rgbcw_lightbulb.yaml**
   - Removed deprecated `number.timer` entity (lines 127-144)
   - Kept existing `time.timer` entity (lines 116-126)

2. **custom_components/tuya_local/devices/diivoo_wt05.yaml**
   - Removed deprecated `number` entities for irrigation_time_1 and irrigation_time_2 (lines 82-113)
   - Kept existing `time.irrigation_time_1` and `time.irrigation_time_2` entities

3. **custom_components/tuya_local/devices/diivoo_dwv010.yaml**
   - Removed deprecated `number` entities for irrigation_time_1 and irrigation_time_2
   - Kept existing `time.*` entities

## Solution Approach
- Located device files in `/home/dev/workspace/home-assistant-config/custom_components/tuya_local/devices/`
- Removed entities marked with `deprecated: time.*` comments (all dated 2025-07-20)
- The replacement `time.*` entities were already present in the files
- All YAML files validated successfully

## Directory Structure Fix
- Merged pulled config files into git repository root properly
- Files now tracked in git at correct paths
- Ready for GitOps deployment workflow

## Git Commit
Committed as: "fix: Remove deprecated Tuya Local number_* entities"
- Commit hash: 3a21ef48
- All changes validated and ready for CI/CD deployment

## Verification
- YAML syntax validated for all modified files
- No more deprecation warnings should appear on next Home Assistant restart
- Modern `time.*` entities will be used instead of deprecated `number_*` entities