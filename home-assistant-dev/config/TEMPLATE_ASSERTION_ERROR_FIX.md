# CRITICAL: Template Assertion Error Fix
## Error: "AssertionError in template_entity.py:584"

### 🚨 ROOT CAUSE IDENTIFIED
**Issue**: Duplicate `unique_id` values across multiple template files causing template assertion failures
**Impact**: System health monitoring sensors failing to update
**Affected Entities**: 
- `binary_sensor.system_health_ok_7`
- `sensor.integration_health_percentage`
- `sensor.alexa_integration_health_5`
- `sensor.mobile_app_integration_health_5`
- `sensor.switch_integration_health_5`

### 📁 CONFLICTING FILES FOUND
**Duplicate unique_id: `integration_health_percentage_fixed`** appears in:
1. `Z:\packages\emergency_health_fix.yaml` ❌
2. `Z:\packages\emergency_health_fix_corrected.yaml` ❌
3. `Z:\packages\system_health_FIXED.yaml` ❌

### ⚡ IMMEDIATE FIX REQUIRED

#### Option 1: Remove Duplicate Files (RECOMMENDED)
**Delete these files from Z:\packages\:**
- `emergency_health_fix.yaml` (original version)
- `emergency_health_fix_corrected.yaml` (duplicate)

**Keep only:**
- `system_health_FIXED.yaml` (most recent/complete version)

#### Option 2: Rename Unique IDs (Alternative)
If files must be kept, change unique_id values in each file:
- File 1: `integration_health_percentage_fixed_v1`
- File 2: `integration_health_percentage_fixed_v2`
- File 3: `integration_health_percentage_fixed_v3`

### 🔧 STEP-BY-STEP RESOLUTION

1. **Backup Current State**
   ```bash
   # Navigate to config directory
   cd /config/packages
   # Create backup
   cp *.yaml /config/backup/packages_backup_$(date +%Y%m%d)/
   ```

2. **Remove Duplicate Files**
   ```bash
   # Delete conflicting files
   rm emergency_health_fix.yaml
   rm emergency_health_fix_corrected.yaml
   # Keep: system_health_FIXED.yaml
   ```

3. **Restart Home Assistant**
   ```
   Settings → System → Restart
   ```

4. **Validate Resolution**
   ```
   Settings → System → Logs
   # Should see no more AssertionError
   ```

### 📊 EXPECTED RESULTS
✅ **Template assertion errors eliminated**
✅ **System health sensors update properly**
✅ **Health monitoring dashboard functional**
✅ **Integration health percentages accurate**

### 🛡️ PREVENTION
- Use unique `unique_id` values across all template files
- Remove old/duplicate template files after fixes
- Test template changes in development before production

### 🔍 VALIDATION COMMANDS
```yaml
# Check if entities are working
states('sensor.integration_health_percentage')
states('binary_sensor.system_health_ok_7')
states('sensor.alexa_integration_health_5')
```

**Should return**: Actual values instead of assertion errors

---
**Priority**: 🔴 CRITICAL - System health monitoring non-functional
**Risk**: Low (cleanup operation)
**Estimated Fix Time**: 5 minutes
