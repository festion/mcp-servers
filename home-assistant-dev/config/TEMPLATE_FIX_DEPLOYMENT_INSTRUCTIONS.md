# TEMPLATE DEPLOYMENT INSTRUCTIONS - CRITICAL FIX
# Date: June 5, 2025
# Purpose: Instructions for applying template duplicate resolution

## IMMEDIATE ACTIONS REQUIRED

### Step 1: Backup Current Configuration
1. Create backup of templates.yaml 
2. Create backup of packages/emergency_health_fix.yaml
3. Create backup of packages/emergency_health_fix_corrected.yaml

### Step 2: Remove Duplicate Package Files
CRITICAL: The duplicate emergency health fix files are causing unique_id conflicts.

**Files to Remove:**
- packages/emergency_health_fix.yaml (keep as backup only)
- packages/emergency_health_fix_corrected.yaml (keep as backup only)

**Replace With:**
- packages/template_conflicts_resolved.yaml (already created with unique IDs)

### Step 3: Update templates.yaml
Replace current templates.yaml with templates_fixed_final.yaml to eliminate:
- Template loop references
- Circular dependencies  
- Numbered sensor references that cause loops

### Step 4: Restart Home Assistant
After file changes, restart HA to load new templates without conflicts.

## EXPECTED RESULTS
- Zero "duplicate unique_id" errors in logs
- Zero "template loop detected" warnings  
- All health monitoring sensors functional
- System stability restored

## FILES CREATED FOR DEPLOYMENT
1. packages/template_conflicts_resolved.yaml - Conflict-free health sensors
2. templates_fixed_final.yaml - Updated main templates without loops
3. This instruction file for deployment reference

## VALIDATION COMMANDS
After restart, check logs for:
- No "Platform template does not generate unique IDs" errors
- No "Template loop detected" warnings
- Health sensors showing proper values