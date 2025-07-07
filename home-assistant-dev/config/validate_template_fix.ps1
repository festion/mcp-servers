# Home Assistant Configuration Validation - Updated for Template Light Fix
# PowerShell version for Windows compatibility

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Home Assistant Configuration Validation (Updated)" -ForegroundColor Yellow
Write-Host "Template Light Fix Validation - $(Get-Date)" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan

# Check if we're in the HA config directory
if (-not (Test-Path "configuration.yaml")) {
    Write-Host "❌ Error: Not in Home Assistant config directory" -ForegroundColor Red
    Write-Host "Please run this script from your HA config directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found Home Assistant configuration directory" -ForegroundColor Green

# Check templates.yaml (should NOT contain light configuration now)
Write-Host ""
Write-Host "Checking templates.yaml (should have no light config)..." -ForegroundColor Yellow
if (Select-String -Path "templates.yaml" -Pattern "- light:" -Quiet) {
    Write-Host "❌ FOUND light configuration in templates.yaml - this should be removed" -ForegroundColor Red
} else {
    Write-Host "✅ No light configuration found in templates.yaml (correct)" -ForegroundColor Green
}

if (Select-String -Path "templates.yaml" -Pattern "state_template|brightness_template" -Quiet) {
    Write-Host "❌ FOUND old template light syntax in templates.yaml" -ForegroundColor Red
} else {
    Write-Host "✅ No old template light syntax found in templates.yaml" -ForegroundColor Green
}

# Check if lights.yaml exists and has correct content
Write-Host ""
Write-Host "Checking lights.yaml configuration..." -ForegroundColor Yellow
if (Test-Path "lights.yaml") {
    Write-Host "✅ lights.yaml file exists" -ForegroundColor Green
    
    if (Select-String -Path "lights.yaml" -Pattern "platform: template" -Quiet) {
        Write-Host "✅ Template platform configured in lights.yaml" -ForegroundColor Green
    } else {
        Write-Host "❌ Template platform not found in lights.yaml" -ForegroundColor Red
    }
    
    if (Select-String -Path "lights.yaml" -Pattern "kitchen_led_strips:" -Quiet) {
        Write-Host "✅ Kitchen LED strips light configured" -ForegroundColor Green
    } else {
        Write-Host "❌ Kitchen LED strips not found in lights.yaml" -ForegroundColor Red
    }
    
    if (Select-String -Path "lights.yaml" -Pattern "value_template:" -Quiet) {
        Write-Host "✅ Proper template light syntax used" -ForegroundColor Green
    } else {
        Write-Host "❌ Template light syntax not found" -ForegroundColor Red
    }
} else {
    Write-Host "❌ lights.yaml file not found" -ForegroundColor Red
}

# Check configuration.yaml for light include
Write-Host ""
Write-Host "Checking configuration.yaml for light include..." -ForegroundColor Yellow
if (Select-String -Path "configuration.yaml" -Pattern "light: !include lights.yaml" -Quiet) {
    Write-Host "✅ Light include directive found in configuration.yaml" -ForegroundColor Green
} else {
    Write-Host "❌ Light include directive missing from configuration.yaml" -ForegroundColor Red
}

# Check customize.yaml updates
Write-Host ""
Write-Host "Checking customize.yaml configuration..." -ForegroundColor Yellow
if (Select-String -Path "customize.yaml" -Pattern "input_datetime.appliance_quiet_start:" -Quiet) {
    Write-Host "✅ Appliance quiet start datetime hidden" -ForegroundColor Green
} else {
    Write-Host "❌ Appliance quiet start datetime not configured" -ForegroundColor Red
}

if (Select-String -Path "customize.yaml" -Pattern "input_datetime.appliance_quiet_end:" -Quiet) {
    Write-Host "✅ Appliance quiet end datetime hidden" -ForegroundColor Green
} else {
    Write-Host "❌ Appliance quiet end datetime not configured" -ForegroundColor Red
}

if (Select-String -Path "customize.yaml" -Pattern "light.kitchen_led_strips:" -Quiet) {
    Write-Host "✅ Kitchen LED strips friendly name configured" -ForegroundColor Green
} else {
    Write-Host "❌ Kitchen LED strips not found in customize.yaml" -ForegroundColor Red
}

# Check required dependencies
Write-Host ""
Write-Host "Checking dependencies..." -ForegroundColor Yellow
if (Select-String -Path "input_boolean.yaml" -Pattern "led_strips_power_status:" -Quiet) {
    Write-Host "✅ LED strips power status input_boolean found" -ForegroundColor Green
} else {
    Write-Host "❌ LED strips power status input_boolean missing" -ForegroundColor Red
}

if (Select-String -Path "input_number.yaml" -Pattern "led_strips_brightness_level:" -Quiet) {
    Write-Host "✅ LED strips brightness input_number found" -ForegroundColor Green
} else {
    Write-Host "❌ LED strips brightness input_number missing" -ForegroundColor Red
}

if (Select-String -Path "input_number.yaml" -Pattern "led_strips_color_temp:" -Quiet) {
    Write-Host "✅ LED strips color temp input_number found" -ForegroundColor Green
} else {
    Write-Host "❌ LED strips color temp input_number missing" -ForegroundColor Red
}

# Check RF scripts
Write-Host ""
Write-Host "Checking RF control scripts..." -ForegroundColor Yellow
if (Test-Path "scripts/led_strips_rf.yaml") {
    Write-Host "✅ LED strips RF scripts found" -ForegroundColor Green
    if (Select-String -Path "scripts/led_strips_rf.yaml" -Pattern "led_strips_rf_power_on:" -Quiet) {
        Write-Host "✅ Power on script found" -ForegroundColor Green
    }
    if (Select-String -Path "scripts/led_strips_rf.yaml" -Pattern "led_strips_rf_power_off:" -Quiet) {
        Write-Host "✅ Power off script found" -ForegroundColor Green
    }
    if (Test-Path "scripts/led_strips.yaml") {
        if (Select-String -Path "scripts/led_strips.yaml" -Pattern "led_strips_set_brightness:" -Quiet) {
            Write-Host "✅ Brightness control script found" -ForegroundColor Green
        }
    }
} else {
    Write-Host "❌ LED strips RF scripts missing" -ForegroundColor Red
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "CONFIGURATION STATUS SUMMARY" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan

$allGood = $true

# Core files check
if (-not (Test-Path "lights.yaml")) { $allGood = $false }
if (Select-String -Path "templates.yaml" -Pattern "- light:" -Quiet) { $allGood = $false }
if (-not (Select-String -Path "configuration.yaml" -Pattern "light: !include lights.yaml" -Quiet)) { $allGood = $false }

if ($allGood) {
    Write-Host ""
    Write-Host "🎉 CONFIGURATION APPEARS CORRECT!" -ForegroundColor Green
    Write-Host "✅ Template light properly configured in lights.yaml" -ForegroundColor Green
    Write-Host "✅ No invalid light config in templates.yaml" -ForegroundColor Green
    Write-Host "✅ Light include directive in configuration.yaml" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor White
    Write-Host "1. Restart Home Assistant" -ForegroundColor Gray
    Write-Host "2. Check for light.kitchen_led_strips entity" -ForegroundColor Gray
    Write-Host "3. Test smart lighting dashboard" -ForegroundColor Gray
    Write-Host "4. Verify RF controls work" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "⚠️  CONFIGURATION ISSUES DETECTED" -ForegroundColor Red
    Write-Host "Please review the errors above and fix before restarting HA" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "TROUBLESHOOTING COMMANDS" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To check configuration before restart:" -ForegroundColor White
Write-Host "  ha core check" -ForegroundColor Gray
Write-Host ""
Write-Host "To restart Home Assistant:" -ForegroundColor White
Write-Host "  ha core restart" -ForegroundColor Gray
Write-Host ""
Write-Host "To check logs for errors:" -ForegroundColor White
Write-Host "  ha logs" -ForegroundColor Gray
Write-Host ""
Write-Host "To verify new entity exists after restart:" -ForegroundColor White
Write-Host "  Check Settings > Devices & Services > Entities" -ForegroundColor Gray
Write-Host "  Search for: light.kitchen_led_strips" -ForegroundColor Gray
