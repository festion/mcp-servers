# Trigger AI Automation Suggester
# This script manually calls the AI automation suggester service

try:
    # Call the AI automation suggester service
    service_data = {
        "all_entities": True,
        "custom_prompt": "Analyze current system for automation improvements, focusing on error handling, device monitoring, and optimization opportunities.",
        "entity_limit": 300
    }
    
    hass.services.call(
        domain="ai_automation_suggester",
        service="generate_suggestions", 
        service_data=service_data
    )
    
    # Create notification about the trigger
    hass.services.call(
        domain="persistent_notification",
        service="create",
        service_data={
            "title": "AI Suggestions Triggered",
            "message": "AI automation suggester has been manually triggered. Check the AI Automation Suggestions sensor for new recommendations.",
            "notification_id": "ai_suggestions_python_trigger"
        }
    )
    
    logger.info("AI automation suggester triggered successfully")
    
except Exception as e:
    logger.error(f"Failed to trigger AI automation suggester: {e}")
    
    # Create error notification
    hass.services.call(
        domain="persistent_notification",
        service="create",
        service_data={
            "title": "AI Suggestions Error",
            "message": f"Failed to trigger AI automation suggester: {e}",
            "notification_id": "ai_suggestions_error"
        }
    )