# MCP 3D Printer Server - Validation Script
# This script validates your configuration and tests the functions

Write-Host "=== MCP 3D Printer Server Validation ===" -ForegroundColor Green

$envPath = ".\.env"
if (-not (Test-Path $envPath)) {
    Write-Host "❌ .env file not found. Run configure_printer.ps1 first." -ForegroundColor Red
    exit 1
}

# Read configuration
$envLines = Get-Content $envPath
$config = @{}
foreach ($line in $envLines) {
    if ($line -match "^([^#=]+)=(.*)$") {
        $config[$matches[1]] = $matches[2]
    }
}

Write-Host "`n=== Configuration Check ===" -ForegroundColor Yellow

# Check required fields
$required = @("PRINTER_TYPE", "PRINTER_HOST", "SLICER_TYPE")
$errors = @()

foreach ($field in $required) {
    if (-not $config[$field] -or $config[$field] -eq "") {
        $errors += "Missing: $field"
        Write-Host "❌ $field not configured" -ForegroundColor Red
    } else {
        Write-Host "✅ $field = $($config[$field])" -ForegroundColor Green
    }
}

# Check slicer path
if ($config.SLICER_PATH -and $config.SLICER_PATH -ne "") {
    if (Test-Path $config.SLICER_PATH) {
        Write-Host "✅ Slicer found at: $($config.SLICER_PATH)" -ForegroundColor Green
    } else {
        $errors += "Slicer not found at: $($config.SLICER_PATH)"
        Write-Host "❌ Slicer not found at: $($config.SLICER_PATH)" -ForegroundColor Red
    }
} else {
    $errors += "SLICER_PATH not configured"
    Write-Host "❌ SLICER_PATH not configured" -ForegroundColor Red
}

# Check slicer profile
if ($config.SLICER_PROFILE -and $config.SLICER_PROFILE -ne "" -and $config.SLICER_PROFILE -ne "default") {
    if (Test-Path $config.SLICER_PROFILE) {
        Write-Host "✅ Slicer profile found: $($config.SLICER_PROFILE)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Slicer profile not found: $($config.SLICER_PROFILE)" -ForegroundColor Yellow
        Write-Host "   Will use default profile" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Using default slicer profile" -ForegroundColor Yellow
}

# Check Bambu-specific configuration
if ($config.PRINTER_TYPE -eq "bambu") {
    if (-not $config.BAMBU_SERIAL -or $config.BAMBU_SERIAL -eq "") {
        $errors += "Bambu printer requires BAMBU_SERIAL"
        Write-Host "❌ BAMBU_SERIAL not configured" -ForegroundColor Red
    } else {
        Write-Host "✅ BAMBU_SERIAL configured" -ForegroundColor Green
    }
    
    if (-not $config.BAMBU_TOKEN -or $config.BAMBU_TOKEN -eq "") {
        $errors += "Bambu printer requires BAMBU_TOKEN"
        Write-Host "❌ BAMBU_TOKEN not configured" -ForegroundColor Red
    } else {
        Write-Host "✅ BAMBU_TOKEN configured" -ForegroundColor Green
    }
} else {
    if (-not $config.API_KEY -or $config.API_KEY -eq "") {
        $errors += "Non-Bambu printers require API_KEY"
        Write-Host "❌ API_KEY not configured" -ForegroundColor Red
    } else {
        Write-Host "✅ API_KEY configured" -ForegroundColor Green
    }
}

Write-Host "`n=== Build Check ===" -ForegroundColor Yellow
try {
    Write-Host "Building server..." -ForegroundColor Cyan
    $buildOutput = & npm run build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build successful" -ForegroundColor Green
    } else {
        $errors += "Build failed"
        Write-Host "❌ Build failed" -ForegroundColor Red
        Write-Host $buildOutput -ForegroundColor Gray
    }
} catch {
    $errors += "Build error: $_"
    Write-Host "❌ Build error: $_" -ForegroundColor Red
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "🎉 All checks passed! Your configuration is ready." -ForegroundColor Green
    Write-Host "`nYou can now:" -ForegroundColor White
    Write-Host "1. Start the server: npm start" -ForegroundColor White
    Write-Host "2. Test functions in Claude:" -ForegroundColor White
    Write-Host "   - get_printer_status" -ForegroundColor Gray
    Write-Host "   - get_stl_info" -ForegroundColor Gray
    Write-Host "   - process_and_print_stl" -ForegroundColor Gray
} else {
    Write-Host "❌ Configuration issues found:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
    Write-Host "`nPlease fix these issues and run this script again." -ForegroundColor Yellow
}

Write-Host "`n=== Configuration File Contents ===" -ForegroundColor Cyan
Get-Content $envPath | ForEach-Object {
    if ($_ -match "^#" -or $_ -eq "") {
        Write-Host $_ -ForegroundColor Gray
    } elseif ($_ -match "(TOKEN|KEY|SERIAL)=(.+)") {
        $key = $_.Split('=')[0]
        Write-Host "$key=***" -ForegroundColor White
    } else {
        Write-Host $_ -ForegroundColor White
    }
}
