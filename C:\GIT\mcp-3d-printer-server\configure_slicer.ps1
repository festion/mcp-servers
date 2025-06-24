# MCP 3D Printer Server - Slicer Configuration Script
# This script helps detect and configure slicer settings

Write-Host "=== MCP 3D Printer Server Slicer Configuration ===" -ForegroundColor Green

# Common slicer installation paths
$slicerPaths = @{
    "PrusaSlicer" = @(
        "C:\Program Files\Prusa3D\PrusaSlicer\prusa-slicer.exe",
        "C:\Program Files (x86)\Prusa3D\PrusaSlicer\prusa-slicer.exe",
        "$env:APPDATA\PrusaSlicer\prusa-slicer.exe"
    )
    "SuperSlicer" = @(
        "C:\Program Files\SuperSlicer\superslicer.exe",
        "C:\Program Files (x86)\SuperSlicer\superslicer.exe"
    )
    "Cura" = @(
        "C:\Program Files\Ultimaker Cura 5.0\UltiMaker-Cura.exe",
        "C:\Program Files\Ultimaker Cura 4.13\Cura.exe",
        "$env:APPDATA\cura\cura.exe"
    )
    "OrcaSlicer" = @(
        "C:\Program Files\OrcaSlicer\OrcaSlicer.exe",
        "C:\Program Files (x86)\OrcaSlicer\OrcaSlicer.exe"
    )
    "BambuStudio" = @(
        "C:\Program Files\Bambu Studio\bambu-studio.exe",
        "C:\Program Files (x86)\Bambu Studio\bambu-studio.exe"
    )
}

# Detect installed slicers
$detectedSlicers = @()
foreach ($slicer in $slicerPaths.Keys) {
    foreach ($path in $slicerPaths[$slicer]) {
        if (Test-Path $path) {
            $detectedSlicers += @{
                Name = $slicer
                Path = $path
                Type = switch ($slicer) {
                    "PrusaSlicer" { "prusaslicer" }
                    "SuperSlicer" { "prusaslicer" }
                    "Cura" { "cura" }
                    "OrcaSlicer" { "orcaslicer" }
                    "BambuStudio" { "prusaslicer" }
                    default { "prusaslicer" }
                }
            }
            Write-Host "✓ Found: $slicer at $path" -ForegroundColor Green
            break
        }
    }
}

if ($detectedSlicers.Count -eq 0) {
    Write-Host "❌ No slicers detected. Please install one of the following:" -ForegroundColor Red
    Write-Host "  - PrusaSlicer: https://www.prusa3d.com/page/prusaslicer_424/"
    Write-Host "  - OrcaSlicer: https://github.com/SoftFever/OrcaSlicer"
    Write-Host "  - Ultimaker Cura: https://ultimaker.com/software/ultimaker-cura"
    Write-Host "  - BambuStudio: https://bambulab.com/en/download/studio"
    exit 1
}

# Let user choose slicer
Write-Host "`n=== Select Slicer ===" -ForegroundColor Yellow
for ($i = 0; $i -lt $detectedSlicers.Count; $i++) {
    Write-Host "$($i + 1). $($detectedSlicers[$i].Name) - $($detectedSlicers[$i].Path)"
}

do {
    $choice = Read-Host "Enter choice (1-$($detectedSlicers.Count))"
    $choiceIndex = [int]$choice - 1
} while ($choiceIndex -lt 0 -or $choiceIndex -ge $detectedSlicers.Count)

$selectedSlicer = $detectedSlicers[$choiceIndex]
Write-Host "Selected: $($selectedSlicer.Name)" -ForegroundColor Green

# Detect profile directories
$profilePaths = @()
switch ($selectedSlicer.Name) {
    "PrusaSlicer" {
        $profilePaths = @(
            "$env:APPDATA\PrusaSlicer\print",
            "$env:APPDATA\PrusaSlicer\printer"
        )
    }
    "OrcaSlicer" {
        $profilePaths = @(
            "$env:APPDATA\OrcaSlicer\system\print",
            "$env:APPDATA\OrcaSlicer\user\print"
        )
    }
    "Cura" {
        $profilePaths = @(
            "$env:APPDATA\cura\quality_changes",
            "$env:APPDATA\cura\quality"
        )
    }
    "BambuStudio" {
        $profilePaths = @(
            "$env:APPDATA\BambuStudio\system\print",
            "$env:APPDATA\BambuStudio\user\print"
        )
    }
}

# Find available profiles
$availableProfiles = @()
foreach ($dir in $profilePaths) {
    if (Test-Path $dir) {
        $profiles = Get-ChildItem $dir -Filter "*.ini" | Select-Object -First 10
        foreach ($profile in $profiles) {
            $availableProfiles += $profile.FullName
        }
    }
}

# Select profile
$selectedProfile = ""
if ($availableProfiles.Count -gt 0) {
    Write-Host "`n=== Available Profiles ===" -ForegroundColor Yellow
    for ($i = 0; $i -lt [Math]::Min($availableProfiles.Count, 10); $i++) {
        $profileName = [System.IO.Path]::GetFileNameWithoutExtension($availableProfiles[$i])
        Write-Host "$($i + 1). $profileName"
    }
    Write-Host "$($availableProfiles.Count + 1). Use default/skip profile"
    
    do {
        $choice = Read-Host "Enter choice (1-$($availableProfiles.Count + 1))"
        $choiceIndex = [int]$choice - 1
    } while ($choiceIndex -lt 0 -or $choiceIndex -gt $availableProfiles.Count)
    
    if ($choiceIndex -lt $availableProfiles.Count) {
        $selectedProfile = $availableProfiles[$choiceIndex]
        Write-Host "Selected profile: $selectedProfile" -ForegroundColor Green
    } else {
        Write-Host "Using default profile" -ForegroundColor Yellow
    }
} else {
    Write-Host "No profiles found. Using default." -ForegroundColor Yellow
}

# Update .env file
$envPath = ".\.env"
$envContent = Get-Content $envPath -Raw

# Update slicer settings
$envContent = $envContent -replace "SLICER_TYPE=.*", "SLICER_TYPE=$($selectedSlicer.Type)"
$envContent = $envContent -replace "SLICER_PATH=.*", "SLICER_PATH=$($selectedSlicer.Path)"
if ($selectedProfile) {
    $envContent = $envContent -replace "SLICER_PROFILE=.*", "SLICER_PROFILE=$selectedProfile"
} else {
    $envContent = $envContent -replace "SLICER_PROFILE=.*", "SLICER_PROFILE="
}

Set-Content $envPath $envContent

Write-Host "`n✅ Configuration Updated!" -ForegroundColor Green
Write-Host "Slicer Type: $($selectedSlicer.Type)" -ForegroundColor Cyan
Write-Host "Slicer Path: $($selectedSlicer.Path)" -ForegroundColor Cyan
Write-Host "Slicer Profile: $($selectedProfile ? $selectedProfile : 'default')" -ForegroundColor Cyan

Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Configure your printer settings in .env file"
Write-Host "2. Test with: npm run test"
Write-Host "3. Run the server: npm start"
