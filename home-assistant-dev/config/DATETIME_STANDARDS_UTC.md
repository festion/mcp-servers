# PROJECT DATETIME STANDARDS - UTC GLOBAL STANDARD
# Date: June 9, 2025
# Purpose: Establish UTC as the universal datetime standard for the entire Home Assistant project

# =============================================================================
# DATETIME STANDARDS FOR HOME ASSISTANT PROJECT
# =============================================================================

# GLOBAL STANDARD: UTC (Coordinated Universal Time)
# ISO 8601 Format: YYYY-MM-DDTHH:MM:SS+00:00 (with Z suffix for UTC)
# Timestamp Format: Unix epoch seconds (float) - always UTC-based

# =============================================================================
# IMPLEMENTATION PRINCIPLES
# =============================================================================

# 1. ALL datetime calculations use UTC timestamps
# 2. ALL storage uses UTC datetime strings  
# 3. ALL displays show local time with UTC reference
# 4. ALL automations use timezone-safe calculations
# 5. ALL templates use now().timestamp() for current time

# =============================================================================
# TEMPLATE STANDARDS
# =============================================================================

# ✅ CORRECT: UTC timestamp-based calculations
# current_timestamp: "{{ now().timestamp() }}"
# stored_timestamp: "{{ state_attr('input_datetime.entity', 'timestamp') | float(0) }}"
# time_diff_hours: "{{ ((current_timestamp - stored_timestamp) / 3600) | round(1) }}"

# ❌ INCORRECT: Mixed timezone datetime objects
# time_diff_hours: "{{ (now() - strptime(stored_time, '%Y-%m-%d %H:%M:%S')).total_seconds() / 3600 }}"

# =============================================================================
# STORAGE STANDARDS
# =============================================================================

# ✅ CORRECT: Store UTC datetime in input_datetime entities
# service: input_datetime.set_datetime
# data:
#   datetime: "{{ utcnow().strftime('%Y-%m-%d %H:%M:%S') }}"

# ✅ CORRECT: Store UTC timestamp for calculations
# timestamp_value: "{{ utcnow().timestamp() }}"

# =============================================================================
# DISPLAY STANDARDS
# =============================================================================

# ✅ CORRECT: Display local time with UTC reference
# Local: "{{ as_timestamp(states('input_datetime.entity')) | timestamp_local }}"
# UTC: "{{ as_timestamp(states('input_datetime.entity')) | timestamp_utc }}"

# =============================================================================
# AUTOMATION STANDARDS
# =============================================================================

# ✅ CORRECT: UTC-based time triggers
# trigger:
#   - platform: time
#     at: "{{ (utcnow().replace(hour=10, minute=0, second=0)).strftime('%H:%M:%S') }}"

# ✅ CORRECT: Duration calculations
# variables:
#   start_timestamp: "{{ state_attr('input_datetime.start_time', 'timestamp') | float(0) }}"
#   current_timestamp: "{{ utcnow().timestamp() }}"
#   elapsed_hours: "{{ ((current_timestamp - start_timestamp) / 3600) | round(1) }}"

# =============================================================================
# LOGGING STANDARDS
# =============================================================================

# ✅ CORRECT: UTC timestamps in log messages
# message: "Process started at {{ utcnow().isoformat() }}Z (UTC)"

# =============================================================================
# NOTIFICATION STANDARDS
# =============================================================================

# ✅ CORRECT: User-friendly local time with UTC reference
# message: "Started {{ elapsed_hours }}h ago ({{ as_timestamp(start_time) | timestamp_local }})"

# =============================================================================
# ENTITY NAMING STANDARDS
# =============================================================================

# UTC-related entities should have clear naming:
# - input_datetime.process_start_time_utc
# - sensor.process_elapsed_hours_utc
# - sensor.process_completion_estimate_utc

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Template to validate UTC timestamp:
# is_valid_utc_timestamp: >
#   {% set ts = value | float(0) %}
#   {{ ts > 0 and ts < (utcnow().timestamp() + 86400) }}

# Template to convert local display:
# local_display_time: >
#   {% if timestamp > 0 %}
#     {{ timestamp | timestamp_local }}
#   {% else %}
#     Unknown
#   {% endif %}

# =============================================================================
# ERROR PREVENTION
# =============================================================================

# Always use these patterns to prevent datetime errors:
# 1. Use .timestamp() for all calculations
# 2. Use utcnow() instead of now() for storage
# 3. Use as_timestamp() for entity datetime conversion
# 4. Use float(0) default for timestamp extraction
# 5. Validate timestamps > 0 before calculations

# =============================================================================
# MIGRATION CHECKLIST
# =============================================================================

# For existing automations/templates:
# □ Replace strptime() with state_attr('entity', 'timestamp')
# □ Replace now() with utcnow() for storage operations
# □ Replace now() with now().timestamp() for calculations
# □ Add UTC validation for all timestamp variables
# □ Update display templates to show local time properly
# □ Add UTC reference to user-facing datetime displays
# □ Update all log messages to use UTC timestamps
# □ Ensure all input_datetime entities store UTC

# =============================================================================
# PROJECT-WIDE COMPLIANCE
# =============================================================================

# This standard applies to:
# ✅ All automations (curatron, health monitoring, equipment)
# ✅ All templates (health calculations, status displays)
# ✅ All dashboard displays (completion dates, elapsed times)
# ✅ All logging (system logs, debug messages)
# ✅ All notifications (mobile alerts, status updates)
# ✅ All database storage (recorder, history)

# =============================================================================
# BENEFITS OF UTC STANDARDIZATION
# =============================================================================

# 1. Eliminates timezone confusion and calculation errors
# 2. Ensures consistent behavior across daylight saving changes
# 3. Provides reliable automation timing regardless of location
# 4. Enables accurate duration calculations and scheduling
# 5. Simplifies troubleshooting with universal time reference
# 6. Future-proofs system for timezone configuration changes
# 7. Enables accurate cross-system time coordination
# 8. Provides professional-grade time handling standards