# 🚨 CRITICAL: Template Assertion Error Fix
## Production Server: Z:\packages\

## ⚠️ IMMEDIATE ACTION REQUIRED

**Error**: `AssertionError` in template entities causing system health monitoring failure
**Root Cause**: Duplicate `unique_id` values in multiple template files
**Impact**: System health monitoring completely non-functional

---

## 🔥 **CRITICAL FILES TO DELETE FROM Z:\packages\**

**DELETE THESE 2 FILES IMMEDIATELY**:
1. ❌ `emergency_health_fix.yaml`
2. ❌ `emergency_health_fix_corrected.yaml`

**KEEP THIS FILE**:
3. ✅ `system_health_FIXED.yaml` (working version)

---

## 🎯 **EXACT STEPS TO EXECUTE**

### Step 1: Delete Duplicate Files
```bash
# Navigate to production server
cd Z:\packages\

# Delete the duplicate files
rm emergency_health_fix.yaml
rm emergency_health_fix_corrected.yaml
```

### Step 2: Restart Home Assistant
- **Developer Tools** → **YAML** → **Restart**
- OR **Settings** → **System** → **Restart**

### Step 3: Validate Fix
Check these entities are working:
- `binary_sensor.system_health_ok_7`
- `sensor.integration_health_percentage`
- `sensor.alexa_integration_health_5`
- `sensor.mobile_app_integration_health_5`
- `sensor.switch_integration_health_5`

---

## 🔍 **WHY THIS FIXES THE ISSUE**

**Problem**: Multiple template files define the same `unique_id: "integration_health_percentage_fixed"`
**Result**: Home Assistant template engine fails with AssertionError
**Solution**: Remove duplicate definitions, keep only the working version

---

## ⏱️ **EXECUTION TIMELINE**

**Urgency**: IMMEDIATE (system monitoring is down)
**Estimated Time**: 5 minutes
**Downtime**: ~2 minutes (restart only)
**Risk**: MINIMAL (removing duplicates only)

---

## 📊 **EXPECTED RESULTS**

**Before Fix**:
- ❌ AssertionError in logs every update cycle
- ❌ System health monitoring non-functional
- ❌ Integration health calculations failing

**After Fix**:
- ✅ No more AssertionError messages
- ✅ System health monitoring restored
- ✅ All integration health sensors working
- ✅ Health dashboard functional

---

## 🔄 **VALIDATION COMMANDS**

After restart, check in **Developer Tools** → **States**:
```yaml
binary_sensor.system_health_ok_7     # Should show "on" 
sensor.integration_health_percentage # Should show percentage
sensor.alexa_integration_health_5    # Should show "100.0"
```

---

**Priority**: 🔴 CRITICAL  
**Action**: Delete 2 duplicate files from Z:\packages\  
**Timeline**: Execute immediately during next access window
