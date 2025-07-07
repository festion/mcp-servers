# Copy Home Assistant Configuration Files Script
# This script copies HA config files to the working directory for analysis

param(
    [string]$SourcePath = "Z:\",
    [string]$DestPath = "C:\working\ha-config\"
)

Write-Host "Home Assistant File Copy Script" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# Create destination directory
if (!(Test-Path $DestPath)) {
    New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
    Write-Host "Created directory: $DestPath" -ForegroundColor Green
}

# Files to copy
$filesToCopy = @(
    "configuration.yaml",
    "automations.yaml", 
    "scripts.yaml",
    "scenes.yaml",
    "groups.yaml",
    "customize.yaml",
    "secrets.yaml"
)

Write-Host "Copying files from $SourcePath to $DestPath..." -ForegroundColor Yellow

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $SourcePath $file
    if (Test-Path $sourcePath) {
        try {
            Copy-Item $sourcePath $DestPath -Force
            Write-Host "✅ Copied: $file" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to copy: $file - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  File not found: $file" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Copy operation completed!" -ForegroundColor Green
Write-Host "Files copied to: $DestPath" -ForegroundColor Cyan
