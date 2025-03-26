# GitOps Git Repository Audit Script (PowerShell)

# Ensure output directory exists
$OutputDir = "output"
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Output report path
$OutputPath = "$OutputDir/GitRepoReport.md"
Set-Content -Path $OutputPath -Value "# Git Repository Audit Report`n"

# Discover Git repositories in current directory
$GitDirs = Get-ChildItem -Directory | Where-Object {
    Test-Path "$($_.FullName)\.git"
}

foreach ($dir in $GitDirs) {
    Write-Host "🔍 Auditing: $($dir.Name)"
    Add-Content -Path $OutputPath -Value "## $($dir.Name)"

    try {
        Set-Location -Path $dir.FullName

        # Remote URL
        $remote = git remote get-url origin 2>$null
        if (-not $remote) {
            Add-Content -Path $OutputPath -Value "- ❌ No remote 'origin' set."
        } else {
            Add-Content -Path $OutputPath -Value "- 🔗 Remote: $remote"
        }

        # Uncommitted changes
        $status = git status --porcelain
        if ($status) {
            Add-Content -Path $OutputPath -Value "- ⚠️ Uncommitted changes detected."
        } else {
            Add-Content -Path $OutputPath -Value "- ✅ Working directory clean."
        }

        # Ahead/behind
        git fetch origin 2>$null
        $summary = git status -sb
        if ($summary -match "ahead") {
            Add-Content -Path $OutputPath -Value "- 🔼 Local branch is ahead of remote."
        }
        if ($summary -match "behind") {
            Add-Content -Path $OutputPath -Value "- 🔽 Local branch is behind remote."
        }
        if ($summary -notmatch "ahead|behind") {
            Add-Content -Path $OutputPath -Value "- 📍 In sync with remote."
        }

    } catch {
        Add-Content -Path $OutputPath -Value "- ❌ Error auditing $($dir.Name): $($_.Exception.Message)"
        Write-Host "❌ Error auditing $($dir.Name): $($_.Exception.Message)"
    } finally {
        Set-Location -Path $PSScriptRoot
        Add-Content -Path $OutputPath -Value ""
    }
}

Write-Host "✅ GitOps audit completed. Report written to $OutputPath"