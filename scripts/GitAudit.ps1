# GitAudit.ps1
$ErrorActionPreference = "Stop"

# Set root paths relative to script location
$scriptRoot = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$gitRoot = $repoRoot
$outputPath = Join-Path $repoRoot "output\GitRepoReport.md"

# Create output folder if missing
if (-not (Test-Path -Path (Join-Path $repoRoot "output"))) {
    New-Item -ItemType Directory -Path (Join-Path $repoRoot "output") | Out-Null
}

# Initialize report content
$report = @()

# Find all directories with a .git folder (recursively)
$repos = Get-ChildItem -Path $gitRoot -Recurse -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName ".git")
}

foreach ($repo in $repos) {
    $repoPath = $repo.FullName
    $repoName = Split-Path $repoPath -Leaf

    try {
        Push-Location $repoPath

        $remote = git remote get-url origin 2>$null
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $lastCommit = git log -1 --pretty=format:"%h - %s (%cr)" 2>$null
        $uncommitted = git status --porcelain
        $isDirty = if ($uncommitted) { "Yes" } else { "No" }

        $missingFiles = @()
        foreach ($file in @(".gitignore", "README.md", "LICENSE")) {
            if (-not (Test-Path (Join-Path $repoPath $file))) {
                $missingFiles += $file
            }
        }

        # Check for stale repos (90+ days)
        $lastCommitDate = git log -1 --format=%ci | Out-String
        $daysOld = 0
        if ($lastCommitDate) {
            $commitDate = [datetime]::Parse($lastCommitDate.Trim())
            $daysOld = (Get-Date) - $commitDate
        }
        $isStale = if ($daysOld.Days -ge 90) { "Yes" } else { "No" }

        # Add to report
        $report += "### $repoName"
        $report += "- Remote: " + ($remote -ne $null ? $remote : "Not set")
        $report += "- Branch: $branch"
        $report += "- Last Commit: $lastCommit"
        $report += "- Uncommitted Changes: $isDirty"
        $report += "- Missing Files: " + ($(if ($missingFiles) { $missingFiles -join ", " } else { "None" }))
        $report += "- Stale (>90 days): $isStale"
        $report += ""
    }
    catch {
        $report += "### $repoName"
        $report += "- ❌ Error reading repository: $_"
        $report += ""
    }
    finally {
        Pop-Location
    }
}

# Summary Section
$total = $repos.Count
$dirty = ($report -match "Uncommitted Changes: Yes").Count
$stale = ($report -match "Stale \(>90 days\): Yes").Count
$noRemote = ($report -match "Remote: Not set").Count

$summary = @()
$summary += "# GitOps Audit Summary"
$summary += ""
$summary += "- Total Repositories: $total"
$summary += "- Repos with Uncommitted Changes: $dirty"
$summary += "- Repos with No Remote Set: $noRemote"
$summary += "- Repos with Stale Commits (90+ days): $stale"
$summary += ""
$summary += "---`n"

# Write report to markdown
$summary + $report | Set-Content -Path $outputPath -Encoding UTF8
Write-Host "✅ GitOps audit complete. Report saved to: $outputPath"
