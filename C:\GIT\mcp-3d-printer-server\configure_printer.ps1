# MCP 3D Printer Server - Complete Configuration Script
# This script helps configure all printer and slicer settings

Write-Host "=== MCP 3D Printer Server Configuration Wizard ===" -ForegroundColor Green

$envPath = ".\.env"
if (-not (Test-Path $envPath)) {
    Copy-Item ".\.env.example" $envPath
    Write-Host "Created .env file from example" -ForegroundColor Yellow
}

# Read current configuration
$envLines = Get-Content $envPath
$currentConfig = @{}
foreach ($line in $envLines) {
    if ($line -match "^([^#=]+)=(.*)$") {
        $currentConfig[$matches[1]] = $matches[2]
    }
}

Write-Host "`n=== Current Configuration ===" -ForegroundColor Cyan
Write-Host "Printer Type: $($currentConfig.PRINTER_TYPE)" -ForegroundColor White
Write-Host "Printer Host: $($currentConfig.PRINTER_HOST)" -ForegroundColor White
Write-Host "Slicer Type: $($currentConfig.SLICER_TYPE)" -ForegroundColor White
Write-Host "Slicer Path: $($currentConfig.SLICER_PATH)" -ForegroundColor White

Write-Host "`n=== Printer Configuration ===" -ForegroundColor Yellow

# Printer Type Selection
$printerTypes = @(
    @{ Name = "OctoPrint"; Type = "octoprint"; Description = "OctoPrint server (most common)" },
    @{ Name = "Klipper"; Type = "klipper"; Description = "Klipper firmware with API" },
    @{ Name = "Duet"; Type = "duet"; Description = "Duet Web Control" },
    @{ Name = "Repetier"; Type = "repetier"; Description = "Repetier Server" },
    @{ Name = "Bambu Lab"; Type = "bambu"; Description = "Bambu Lab printers (X1, P1P, A1)" },
    @{ Name = "Prusa Connect"; Type = "prusa"; Description = "Prusa MINI/MK4 with Connect" },
    @{ Name = "Creality"; Type = "creality"; Description = "Creality Sonic Pad/Cloud" }
)

Write-Host "Select your printer type:"
for ($i = 0; $i -lt $printerTypes.Count; $i++) {
    Write-Host "$($i + 1). $($printerTypes[$i].Name) - $($printerTypes[$i].Description)"
}

do {
    $choice = Read-Host "Enter choice (1-$($printerTypes.Count))"
    $choiceIndex = [int]$choice - 1
} while ($choiceIndex -lt 0 -or $choiceIndex -ge $printerTypes.Count)

$selectedPrinter = $printerTypes[$choiceIndex]
Write-Host "Selected: $($selectedPrinter.Name)" -ForegroundColor Green

# Printer connection details
$printerHost = Read-Host "Enter printer IP address [$($currentConfig.PRINTER_HOST)]"
if (-not $printerHost) { $printerHost = $currentConfig.PRINTER_HOST }

$printerPort = Read-Host "Enter printer port [80]"
if (-not $printerPort) { $printerPort = "80" }

$apiKey = ""
if ($selectedPrinter.Type -ne "bambu") {
    $apiKey = Read-Host "Enter API key [$($currentConfig.API_KEY)]"
    if (-not $apiKey) { $apiKey = $currentConfig.API_KEY }
}

# Bambu-specific configuration
$bambuSerial = ""
$bambuToken = ""
if ($selectedPrinter.Type -eq "bambu") {
    Write-Host "`n=== Bambu Lab Configuration ===" -ForegroundColor Yellow
    Write-Host "For Bambu printers, you need:"
    Write-Host "1. Printer serial number (found on printer or in app)"
    Write-Host "2. Access token (from Bambu Studio or app settings)"
    
    $bambuSerial = Read-Host "Enter Bambu printer serial number"
    $bambuToken = Read-Host "Enter Bambu access token"
}

# Update configuration in memory
$newConfig = @{
    "PRINTER_TYPE" = $selectedPrinter.Type
    "PRINTER_HOST" = $printerHost
    "PRINTER_PORT" = $printerPort
    "API_KEY" = $apiKey
    "BAMBU_SERIAL" = $bambuSerial
    "BAMBU_TOKEN" = $bambuToken
}

Write-Host "`n=== Configuration Summary ===" -ForegroundColor Green
Write-Host "Printer Type: $($newConfig.PRINTER_TYPE)" -ForegroundColor White
Write-Host "Printer Host: $($newConfig.PRINTER_HOST)" -ForegroundColor White
Write-Host "Printer Port: $($newConfig.PRINTER_PORT)" -ForegroundColor White
if ($newConfig.API_KEY) {
    Write-Host "API Key: $($newConfig.API_KEY.Substring(0, [Math]::Min(8, $newConfig.API_KEY.Length)))***" -ForegroundColor White
}
if ($newConfig.BAMBU_SERIAL) {
    Write-Host "Bambu Serial: $($newConfig.BAMBU_SERIAL)" -ForegroundColor White
    Write-Host "Bambu Token: $($newConfig.BAMBU_TOKEN.Substring(0, [Math]::Min(8, $newConfig.BAMBU_TOKEN.Length)))***" -ForegroundColor White
}

$confirm = Read-Host "`nSave this configuration? (y/n)"
if ($confirm -eq "y" -or $confirm -eq "Y") {
    # Update .env file
    $envContent = Get-Content $envPath -Raw
    
    foreach ($key in $newConfig.Keys) {
        $value = $newConfig[$key]
        if ($envContent -match "$key=") {
            $envContent = $envContent -replace "$key=.*", "$key=$value"
        } else {
            $envContent += "`n$key=$value"
        }
    }
    
    Set-Content $envPath $envContent
    Write-Host "✅ Configuration saved to .env" -ForegroundColor Green
    
    # Test connection
    Write-Host "`n=== Testing Connection ===" -ForegroundColor Yellow
    Write-Host "Building and testing server..." -ForegroundColor Cyan
    
    try {
        & npm run build
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Build successful" -ForegroundColor Green
        } else {
            Write-Host "❌ Build failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Build error: $_" -ForegroundColor Red
    }
    
} else {
    Write-Host "Configuration not saved." -ForegroundColor Yellow
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Run slicer configuration: .\configure_slicer.ps1"
Write-Host "2. Test the server: npm run test"
Write-Host "3. Start the server: npm start"
Write-Host "4. In Claude, test with: get_printer_status"
