$gitRoot = "C:\GIT"
$outputFile = "GitRepoReport.md"
$report = @()

Write-Host "Scanning Git repositories in $gitRoot..."
$repos = Get-ChildItem -Path $gitRoot -Directory

foreach ($repo in $repos) {
    $repoPath = Join-Path $gitRoot $repo.Name
    $gitFolder = Join-Path $repoPath ".git"

    if (Test-Path $gitFolder) {
        Write-Host ""
        Write-Host "Repo: $($repo.Name)"
        Set-Location $repoPath

        $remote = git remote get-url origin 2>$null
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $lastCommit = git log -1 --pretty=format:"%h - %s (%cr)" 2>$null
        $uncommitted = git status --porcelain

        $missingFiles = @()
        foreach ($file in @(".gitignore", "README.md", "LICENSE")) {
            if (-not (Test-Path "$repoPath\$file")) {
                $missingFiles += $file
            }
        }

        if ($remote) {
            Write-Host "  Remote: $remote"
        } else {
            Write-Host "  Remote: Not set"
        }

        Write-Host "  Branch: $branch"
        Write-Host "  Last commit: $lastCommit"

        if ($uncommitted) {
            Write-Host "  Uncommitted changes: Yes"
        }

        if ($missingFiles.Count -gt 0) {
            Write-Host "  Missing files: $($missingFiles -join ', ')"
        }

        # Build report lines
        $remoteDisplay = if ($remote) { $remote } else { "Not set" }
        $dirtyDisplay = if ($uncommitted) { "Yes" } else { "No" }
        $missingDisplay = if ($missingFiles.Count -gt 0) { $missingFiles -join ", " } else { "None" }

        $report += "### $($repo.Name)"
        $report += "- Remote: $remoteDisplay"
        $report += "- Branch: $branch"
        $report += "- Last Commit: $lastCommit"
        $report += "- Uncommitted Changes: $dirtyDisplay"
        $report += "- Missing Files: $missingDisplay"
        $report += ""

        Set-Location $gitRoot
    } else {
        Write-Host ""
        Write-Host "Skipping non-Git folder: $($repo.Name)"
    }
}

$report | Set-Content -Path $outputFile -Encoding UTF8
Write-Host ""
Write-Host "Report saved to: $outputFile"
Write-Host "Audit complete."
