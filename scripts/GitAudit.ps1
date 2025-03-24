# GitAudit.ps1 - Compatible with Windows PowerShell 5.1

$ErrorActionPreference = "Stop"

# Set the root folder where your Git repos are stored
$repoRoot = "C:\GIT"

# Set output paths
$outputDir = Join-Path $PSScriptRoot "..\output"
$outputMd = Join-Path $outputDir "GitRepoReport.md"
$outputJson = Join-Path $outputDir "GitRepoReport.json"

# Create output directory if it doesn't exist
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Prepare containers
$reportMd = @()
$reportJson = @()

# Find all Git repos recursively
$repos = Get-ChildItem -Path $repoRoot -Recurse -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName ".git")
}

foreach ($repo in $repos) {
    $repoPath = $repo.FullName
    $repoName = Split-Path $repoPath -Leaf
    $repoInfo = @{
        name = $repoName
        path = $repoPath
    }

    Push-Location $repoPath

    try {
        $remote = git remote get-url origin 2>$null
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $lastCommit = git log -1 --pretty=format:"%h - %s" 2>$null
        $lastCommitDateRaw = git log -1 --format=%ci 2>$null
        $uncommitted = git status --porcelain
        $isDirty = [bool]$uncommitted

        $commitAgeDays = 0
        if ($lastCommitDateRaw) {
            $commitDate = [datetime]::Parse($lastCommitDateRaw.Trim())
            $commitAgeDays = (New-TimeSpan -Start $commitDate -End (Get-Date)).Days
        }

        $missingFiles = @()
        foreach ($file in @(".gitignore", "README.md", "LICENSE")) {
            if (-not (Test-Path "$repoPath\$file")) {
                $missingFiles += $file
            }
        }

        # Add to JSON report
        $repoInfo += @{
            remote = $remote
            branch = $branch
            lastCommit = $lastCommit
            lastCommitAgeDays = $commitAgeDays
            uncommittedChanges = $isDirty
            missingFiles = $missingFiles
            isStale = ($commitAgeDays -ge 90)
        }

        # Add to Markdown report
        $reportMd += "### $repoName"
        $reportMd += "- Remote: " + $(if ($remote) { $remote } else { "Not set" })
        $reportMd += "- Branch: $branch"
        $reportMd += "- Last Commit: $lastCommit"
        $reportMd += "- Uncommitted Changes: " + $(if ($isDirty) { "Yes" } else { "No" })
        $reportMd += "- Missing Files: " + $(if ($missingFiles) { $missingFiles -join ", " } else { "None" })
        $reportMd += "- Stale (>90 days): " + $(if ($commitAgeDays -ge 90) { "Yes" } else { "No" })
        $reportMd += ""
    }
    catch {
        $repoInfo["error"] = $_.Exception.Message
        $reportMd += "### $repoName"
        $reportMd += "- ❌ Error: $($_.Exception.Message)"
        $reportMd += ""
    }

    $reportJson += $repoInfo
    Pop-Location
}

# Summary
$total = $repos.Count
$dirty = ($reportJson | Where-Object { $_.uncommittedChanges }).Count
$stale = ($reportJson | Where-Object { $_.isStale }).Count
$noRemote = ($reportJson | Where-Object { !$_.remote }).Count

$summary = @()
$summary += "# GitOps Audit Summary"
$summary += ""
$summary += "- Total Repositories: $total"
$summary += "- Repos with Uncommitted Changes: $dirty"
$summary += "- Repos with No Remote Set: $noRemote"
$summary += "- Repos with Stale Commits (90+ days): $stale"
$summary += ""
$summary += "---`n"

# Write reports
$summary + $reportMd | Set-Content -Path $outputMd -Encoding UTF8
$reportJson | ConvertTo-Json -Depth 4 | Set-Content -Path $outputJson -Encoding UTF8

Write-Host "GitOps audit complete."
Write-Host "Markdown report: $outputMd"
Write-Host "JSON report: $outputJson"
